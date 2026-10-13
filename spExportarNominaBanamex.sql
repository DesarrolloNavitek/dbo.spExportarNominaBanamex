SET DATEFIRST 7
SET ANSI_NULLS OFF
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED
SET LOCK_TIMEOUT -1
SET QUOTED_IDENTIFIER OFF
GO
CREATE OR ALTER PROCEDURE spExportarNominaBanamex
	@Empresa	CHAR(5),                          
	@Ejercicio  int,                          
	@Mov		varchar(20),                          
	@MovID		varchar(20),                          
	@CtaDinero  CHAR(10)
WITH ENCRYPTION
AS            
BEGIN                          

	CREATE TABLE #Nomina                          
	(
		Cadena2 VARCHAR(max)
	)
	
	CREATE TABLE #Personal                          
	(
		TipoReg				VARCHAR(1) COLLATE Database_Default,                          
		TipoOper			VARCHAR(1) COLLATE Database_Default,                          
		MetodoPago			VARCHAR(3) COLLATE Database_Default,                          
		OrdenPago			VARCHAR(2)  COLLATE Database_Default,                          
		CveMoneda			VARCHAR(3) COLLATE Database_Default,                          
		TipoCta				VARCHAR(2) COLLATE Database_Default,                          
		PersonalSucursal	VARCHAR(4) COLLATE Database_Default,                          
		Referencia			VARCHAR(40) COLLATE Database_Default,                          
		Instrucciones		VARCHAR(10) COLLATE Database_Default,                          
		DescTEF				VARCHAR(24) COLLATE Database_Default,                          
		CveBanco			VARCHAR(4) COLLATE Database_Default,                          
		RefVal				VARCHAR(7) COLLATE Database_Default,                          
		Plazo				VARCHAR(2) COLLATE Database_Default,                          
		Personal			VARCHAR(10) COLLATE Database_Default,                          
		Empleado			VARCHAR(55) COLLATE Database_Default,                          
		PersonalCuenta		VARCHAR(20) COLLATE Database_Default,                          
		importe				DECIMAL (10,2)
	)                          

	DECLARE                          
		@FechaNom		VARCHAR(10),                          
		@NomEmpresa		VARCHAR(36),                          
		@ImpTotal		INT,                          
		@ImpStr			VARCHAR(18),                          
		@Continua		BIT,                          
		@MsgError		VARCHAR(221),                          
		@NoPersonal		INT,
		@TipoPeriodo	varchar(10)

	SELECT @Continua = 1                          
	IF NOT EXISTS(SELECT TOP(1) 0 FROM Empresa WHERE Empresa = @Empresa) OR NOT EXISTS (SELECT TOP(1) 0 FROM CtaDinero WHERE Institucion = 'CITIBANAMEX' AND CtaDinero = @CtaDinero)                          
	BEGIN                          
		SELECT @Continua=0                          
		SELECT @MsgError='Error en los parametros proporcionados. Corrigelo'                          
	END                          

	IF @Continua=1                          
	BEGIN

		--SELECT @FechaNom = convert(varchar,dateadd(day, 2, getdate()),102)
		--JARC 23/04/2026 PARA QUE TOME LA FECHA DE PAGO EN LA NOMINA
		SELECT @TipoPeriodo = TipoPeriodo FROM Nomina WHERE MovID  =@MovID AND Mov = @Mov AND Empresa = @Empresa AND Ejercicio = @Ejercicio
		
		SELECT @FechaNom =  CASE WHEN @TipoPeriodo = 'Semanal' THEN (SELECT  CONVERT(VARCHAR,FechaPago,102) 
																	   FROM  Nomina a 
																	   LEFT JOIN nvk_tb_IncidenciasSemanal b ON a.NoPeriodo=b.Semana
																	  WHERE a.Ejercicio = @Ejercicio
																		AND a.Mov = @Mov
																		AND a.MovID = @MovID 
																		AND a.Empresa = @Empresa)
																ELSE
																(SELECT  CONVERT(VARCHAR,FechaPago,102) 
																	   FROM  Nomina a 
																	   LEFT JOIN nvk_tb_IncidenciasQuincenal b ON a.NoPeriodo=b.Periodo
																	  WHERE a.Ejercicio = @Ejercicio
																		AND a.Mov = @Mov
																		AND a.MovID = @MovID 
																		AND a.Empresa = @Empresa)
																END
																
		SELECT @FechaNom = substring(@FechaNom,3,2) + substring(@FechaNom,6,2) + substring(@FechaNom,9,2)                          
		SELECT @NomEmpresa = ISNULL(Nombre,'') FROM Empresa WHERE Empresa=@Empresa

		IF @NomEmpresa != ''
		BEGIN
			SELECT @NomEmpresa = REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(@NomEmpresa, 'á', 'a'), 'é', 'e'), 'í', 'i'), 'ó', 'o'), 'ú', 'u'), 'ñ', 'n')
			SELECT @NomEmpresa = REPLACE(REPLACE(REPLACE(@NomEmpresa, CHAR(13), ''), CHAR(10), ''), CHAR(9), '')
			IF @NomEmpresa NOT LIKE '%SA DE CV%' AND @NomEmpresa NOT LIKE '%S.A. DE C.V.%'
			BEGIN
				IF @NomEmpresa LIKE '%S.A. DE C.V.%'
					SELECT @NomEmpresa = REPLACE(@NomEmpresa, 'S.A. DE C.V.', 'SA DE CV')
				ELSE
					SELECT @NomEmpresa = TRIM(@NomEmpresa) + ' SA DE CV'
			END

		END

		IF LEN(@NomEmpresa) < 36
			SELECT @NomEmpresa = @NomEmpresa + SPACE(36 - LEN(@NomEmpresa))
		ELSE IF LEN(@NomEmpresa) > 36
			SELECT @NomEmpresa = LEFT(@NomEmpresa, 36) 

		INSERT INTO #Nomina                          
		SELECT '1' + '000001567207' + @FechaNom + '0001' + @NomEmpresa + @Mov+space(20-len(@Mov)) + '15' + 'D' + '0' + '1'          
      
		INSERT INTO #Personal                          
		SELECT  TipoReg = '3', TipoOper = '0', Metodopago = '001', OrdenPago = '01', CveMoneda = '001', TipoCta = case a.EsSocio WHEN 0 THEN '01' ELSE '01' END,                          
			PersonalSucursal = ISNULL(STUFF('0000', 5 - LEN(PersonalSucursal), LEN(PersonalSucursal), PersonalSucursal),'0000'),                          
			Referencia =a.Personal /*ISNULL(STUFF('0000000000', 11 - LEN(Replace(Replace(Replace(a.Personal,'-','0'),'C','0'),'U','0')), LEN(Replace(Replace(Replace(a.Personal,'-','0'),'C','0'),'U','0')),                          
			Replace(Replace(Replace(a.Personal,'-','0'),'C','0'),'U','0')),'0000000000') + space(29)*/, Instrucciones = @Mov, DescTEF = space(24),                          
			CveBanco = '0000', RefVal = '0000001', Plazo='00', a.Personal,                  
			Empleado=substring(rtrim(Replace(a.Nombre,'Ñ','N')) + ',' +  rtrim(Replace(a.ApellidoPaterno,'Ñ','N')) + '/' + rtrim(isnull(replace(a.ApellidoMaterno,'Ñ','N'),'')),1,55),                          
			a.PersonalCuenta, Importe=(SUM(CASE WHEN c.Movimiento = 'Percepcion' THEN c.Importe ELSE c.Importe * -1 END))                          
		FROM  Personal a, Nomina b, NominaD c                          
		WHERE a.Personal=c.Personal                          
		AND b.ID = c.ID                          
		AND c.Movimiento in ('Percepcion','Deduccion')               
		AND b.Mov      = @Mov                          
		AND b.MovID    = @MovID                          
		AND b.Ejercicio   = @Ejercicio                          
		AND b.Estatus    = 'CONCLUIDO'                          
		AND b.Empresa    = @Empresa                          
		AND c.Concepto   <> 'FACTURA'                          
		AND a.PersonalCuenta IS NOT NULL       
		AND A.FormaPago = 'Transferencia Electronica'      
		--AND A.PersonalSucursal='BANAMEX'                          
		AND c.Importe    <> 0
		AND TRIM(ISNULL(A.PersonalSucursal,'')) = 'BANCO NACIONAL DE MEXICO SA  SUC 266 INSURGENTES S'
		GROUP BY a.Personal, a.PersonalSucursal, a.Nombre, a.ApellidoPaterno, a.ApellidoMaterno, a.PersonalCuenta,a.EsSocio                          

		SELECT  @ImpTotal = ROUND(SUM(Importe),2)*100                          
		FROM #Personal                          

		SELECT @ImpStr = CONVERT(varchar,@ImpTotal)                          
		
		SELECT  @NoPersonal = COUNT(Personal)                          
		FROM #Personal                          
		WHERE  importe > 0                          

		INSERT INTO #Nomina                          
		--SELECT '2' + '1' + '001' + STUFF('000000000000000000', 19 - LEN(@ImpStr), LEN(@ImpStr), @ImpStr) +                          
		--'01' + STUFF('0000', 5 - LEN('0000'), LEN('0000'), '0000') +                          
		--STUFF('00000000000000000000', 17 - LEN(NumeroCta), LEN(NumeroCta), NumeroCta) + convert(varchar,@NoPersonal) /*GF  +'<EOL>'*/                          
		--FROM  CtaDinero                          
		--WHERE Institucion = 'CITIBANAMEX' AND CtaDinero = @CtaDinero       
		
		SELECT '2' + '1' + '001' + RIGHT(REPLICATE('0', 18) + @ImpStr, 18) +                          
		'01' + '0000' +                          
		RIGHT(REPLICATE('0', 16) + NumeroCta, 16) + RIGHT(REPLICATE('0', 6) + CAST(@NoPersonal AS VARCHAR), 6) /*GF  +'<EOL>'*/                          
		FROM  CtaDinero                          
		WHERE Institucion = 'CITIBANAMEX' AND CtaDinero = @CtaDinero

		INSERT INTO #Nomina                          
		SELECT                          
			TipoReg + TipoOper + MetodoPago + OrdenPago + CveMoneda + STUFF('000000000000000000', 19 - LEN(CONVERT(int,ROUND(importe,2)*100)), LEN(CONVERT(int, ROUND(importe,2) * 100)), CONVERT(int, ROUND(importe,2) * 100)) +                          
			TipoCta                           
			+ STUFF('00000000000000000000', 21 - LEN(PersonalCuenta), LEN(PersonalCuenta), PersonalCuenta) +                          
			+ Referencia+SPACE(16 - LEN (Referencia))                    
			--STUFF('0000000000000000', 16 - LEN(Rtrim(Ltrim(Referencia))), LEN(Rtrim(Ltrim(Referencia))), Rtrim(Ltrim(Referencia)))                          
			+ Rtrim(Ltrim(Empleado) )+SPACE(55 - LEN(Ltrim(Empleado)))                          
			+replicate(' ', 35)                          
			+replicate(' ', 35)                          
			+replicate(' ', 35)                          
			+replicate(' ', 35)                          
			--+space(6-len(Instrucciones)) +CveBanco + Plazo + replicate (' ', 152) -- +'<EOL>'                           
			+CveBanco + Plazo + replicate (' ', 152) -- +'<EOL>'                           --DBR
			FROM    #Personal                          
			WHERE   Importe > 0                          

		INSERT INTO #Nomina                          
		SELECT '4' + '001' + STUFF('000000', 7 - LEN(COUNT(Personal)), LEN(COUNT(Personal)),  COUNT(Personal)) +                          
		STUFF('000000000000000000',19-LEN(@ImpStr),LEN(@ImpStr),@ImpStr)+'000001'+STUFF('000000000000000000',19-LEN(@ImpStr),LEN(@ImpStr),@ImpStr)FROM #Personal                          
		WHERE  importe > 0                          

		IF EXISTS (SELECT TOP(1) 0 FROM sysobjects where id = object_id('ExportarNominaBanamex')) DROP TABLE ExportarNominaBanamex                          
    
		SELECT Cadena2 into ExportarNominaBanamex FROM #Nomina                          
			
		--/*JC*/BEGIN      
		--DECLARE @Comando VARCHAR(3048)                          
		--SET @Comando='Exec Master..xp_Cmdshell ''bcp "select cadena2 from Burbutek.dbo.ExportarNominaBanamex" queryout "C:\Documentos\Intelisis\DispersionBURBU\DispersionNominaBanamex.txt" -S (Tocal) -T -c'', NO_OUTPUT'                          
		--EXEC(@Comando)     
  
		DECLARE @Comando VARCHAR(3048)   
  
		--set @Comando='Exec Master..xp_Cmdshell  ''mkdir  C:\Documentos\Intelisis\DispersionBURBU'  
		SET @Comando='Exec Master..xp_Cmdshell ''bcp "select cadena2 from Navilux.dbo.ExportarNominaBanamex" queryout "C:\Documentos\Intelisis\DispersionNAVI\DispersionNominaBanamex.txt" -S (Local) -T -c'', NO_OUTPUT'                        
		EXEC(@Comando)  
  
		--END/*JC*/    
		SELECT  Cadena2 FROM #Nomina                          
	END                          
	ELSE                          
		SELECT @MsgError Cadena       
     
END
GO
