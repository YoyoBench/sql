/*
CREATE TABLE [CQC].[dbo].[AdolDep12ClinicScores] (Indexstart Date, IndexEnd Date, Startdate Date, Enddate Date, DateSpan varchar(50), OrgScore DECIMAL(5,2), ComoRoseville DECIMAL(5,2), EastSide DECIMAL(5,2), Highland DECIMAL(5,2), IGH DECIMAL(5,2), NSP DECIMAL(5,2), Shoreview DECIMAL(5,2), Vadnais DECIMAL(5,2),
Banning DECIMAL(5,2), WSP DECIMAL(5,2), Woodbury DECIMAL(5,2))
*/

--Select Indexstart, Indexend, Startdate, CONVERT(varchar,DATEPART(month, Enddate),5)+'/'+CONVERT(varchar,DATEPART(YEAR, Enddate),101) [End],DateSpan,OrgScore,ComoRoseville,EastSide,Highland,IGH,NSP,Shoreview,Vadnais,Banning,WSP,Woodbury from [CQC].[dbo].[AdolDep12ClinicScores] Order By Startdate desc

----------------------------------------------------------
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO
-----------------------------------------------------------

DECLARE @startDate VARCHAR(MAX);
DECLARE @endDate VARCHAR(MAX);
DECLARE @startDate1 VARCHAR(MAX);
DECLARE @endDate1 VARCHAR(MAX);
DECLARE @SixfollowUpStart VARCHAR(MAX);
DECLARE @SixfollowUpEnd VARCHAR(MAX);
DECLARE @IndexedPatients TABLE 
	(
		patientId VARCHAR(50),
		indexDate DATE
	);

--Start Date and End Date should be the reporting period
SET @startDate1 = dateadd(m, -12-5, getdate()-day(getdate())+1);
SET @endDate1 = dateadd(m, -5, getdate()-day(getdate()));

--SET @startDate1 = '08-01-2019';
--SET @endDate1 = '07-31-2020';

--Index Date then changes to start 7 months before the reporting period. This is because follow up runs 6 months later + 60 days. 
SET @startDate = DATEADD(MONTH, - 13, @startDate1);
SET @endDate = DATEADD(DAY, - 1, DATEADD(MONTH, 12, @startDate))
Set @SixfollowUpStart = DATEADD(MONTH, -6, DATEADD(DAY, -60, @startDate));
Set @SixfollowupEnd = DATEADD(MONTH, -6,DATEADD(DAY, -60, @endDate));

WITH AllPHQDates AS
	(
		SELECT 
			MAIN.ControlNo , 
			MAIN.[date] , 
			1 [DateLevel]
		FROM
			(--Anchor query for being recursion
				SELECT  
					MIN( enc.[date] ) [date] ,
					p.ControlNo
				FROM 
					structhpi h
				INNER JOIN 
					enc
						ON enc.encounterID = h.encounterId 
				INNER JOIN 
					patients P 
						ON enc.patientID = P.pid
				INNER JOIN 
					diagnosis d
						ON d.EncounterId = enc.encounterID
				INNER JOIN 
					itemdetail id
						ON id.itemID = d.ItemId
							AND id.propID = 13
				WHERE 
					(
						catId = 257803
						AND h.itemId = 12325
						AND detailId = 15
					)
					AND id.[value] IN 
								(
									'F32.0','F32.1','F32.2','F32.3',
									'F32.4','F32.5','F32.9','F33.0',
									'F33.1','F33.2','F33.3','F33.40',
									'F33.41','F33.42','F33.9','F34.1',
									'296.20','296.21','296.22','296.23',
									'296.24','296.25','296.26','296.30',
									'296.31','296.32','296.33','296.34',
									'296.35','296.36','300.4'
								)
					AND 
					CAST(h.[value] AS VARCHAR(MAX)) IS NOT NULL
					AND 
					CAST(h.[value] AS VARCHAR(MAX)) <> ''
					AND 
					TRY_CAST(CONVERT(VARCHAR(2), h.[value]) AS INT) > 9 
				GROUP BY 
					P.ControlNo
			) MAIN

		UNION ALL 

		SELECT 
			MAIN2.ControlNo , 
			MAIN2.[date] , 
			PHQ.DateLevel + 1 [DateLevel]
		FROM
			(
				SELECT 
					enc.[date],
					p.ControlNo
				FROM 
					structhpi h
				INNER JOIN 
					enc
						ON enc.encounterID = h.encounterId 
				INNER JOIN 
					patients P 
						ON enc.patientID = P.pid
				INNER JOIN 
					diagnosis d
						ON d.EncounterId = enc.encounterID
				INNER JOIN 
					itemdetail id
						ON id.itemID = d.ItemId
							AND id.propID = 13
				WHERE 
					(
						catId = 257803
						AND h.itemId = 12325
						AND detailId = 15
					)
					AND id.[value] IN 
								(
									'F32.0','F32.1','F32.2','F32.3',
									'F32.4','F32.5','F32.9','F33.0',
									'F33.1','F33.2','F33.3','F33.40',
									'F33.41','F33.42','F33.9','F34.1',
									'296.20','296.21','296.22','296.23',
									'296.24','296.25','296.26','296.30',
									'296.31','296.32','296.33','296.34',
									'296.35','296.36','300.4'
								)
					AND 
					CAST(h.[value] AS VARCHAR(MAX)) IS NOT NULL
					AND 
					CAST(h.[value] AS VARCHAR(MAX)) <> ''
					AND 
					TRY_CAST(CONVERT(VARCHAR(2), h.[value]) AS INT) > 9
			) MAIN2
		INNER JOIN 
			AllPHQDates PHQ 
				ON MAIN2.ControlNo = PHQ.ControlNo 
					AND MAIN2.[date] > DATEADD( MONTH , 14 , PHQ.[date] )
	)

INSERT INTO @IndexedPatients
	SELECT 
		ControlNo , 
		MIN( [date] ) [date]
	FROM 
		AllPHQDates 
	GROUP BY 
		ControlNo , 
		DateLevel 
	ORDER BY 
		ControlNo , 
		[date]


INSERT INTO [CQC].[dbo].[AdolDep12ClinicScores] (Indexstart, Indexend, Startdate, Enddate, DateSpan, OrgScore, ComoRoseville, EastSide, Highland, IGH, NSP, Shoreview, Vadnais, Hugo, WSP, Woodbury)

	Select
--top 1000
*
from

(Select 
	CONVERT(date, @startDate) [Indexstart]
	,CONVERT(date, @endDate) [IndexEnd]
	,CONVERT(date, @startDate1) [Startdate]
	,CONVERT(date, @endDate1) [Enddate]
	,CONVERT(varchar(19),CONVERT(date, @startDate1),101)+' - '+CONVERT(varchar(19),CONVERT(date, @endDate1),101) as [Date Span]
	,Clinic AS ItemRename
	,CAST(
	ROUND(
	CAST(COUNT (
		CASE
			WHEN
				[Latest PHQ Score] <> '' and [Latest PHQ Score] < 5
					THEN [Patient Account Number]
		END) AS Decimal)
	/
	COUNT ([Patient Account Number])
	,2) 
		AS DECIMAL (5,2)) [MaxDate]
	,MAX(org.maxdate) [Org Score]
	
FROM 
	(
		SELECT 
			f.[Name] AS [Clinic],
			doc.ulname + ', ' + doc.ufname AS [Provider],
			p.ControlNo AS [Patient Account Number],
			u.ulname AS [Patient Last Name],
			u.ufname AS [Patient First Name],
			CONVERT(VARCHAR(19), PHQ.initDate, 101) AS [Initial PHQ],
			CONVERT(VARCHAR(19), PHQ.followDate, 101) AS [Follow Up Date],
			CASE 
				WHEN PHQ.[value] IS NULL
					THEN ''
				ELSE PHQ.[value]
				END AS [Latest PHQ Score]
		FROM 
			@IndexedPatients indexedPatients
		INNER JOIN 
			patients p
				ON p.ControlNo = indexedPatients.patientId
		INNER JOIN 
			users u
				ON u.[uid] = p.pid
		LEFT JOIN 
			users doc
				ON doc.[uid] = p.doctorId
		LEFT JOIN 
			edi_facilities f
				ON f.Id = doc.primaryservicelocation
		LEFT JOIN 
			edi_facilities patfac
				ON patfac.Id = u.primaryservicelocation
		LEFT JOIN 
			(
				SELECT 
					PHQFollowDate.patientID,
					PHQFollowDate.initDate,
					PHQFollowDate.followDate,
					PHQFollowValue.[value]
				FROM 
					(
						SELECT 
							initital.patientID,
							initital.[date] AS [initDate],
							MAX(Follow.[date]) AS [followDate]
						FROM 
							(
								SELECT 
									indexedPatients.indexDate AS [DATE],
									p.pid AS [patientID]
								FROM 
									@IndexedPatients indexedPatients
								INNER JOIN 
									patients p
										ON p.ControlNo = indexedPatients.patientId
											AND indexedPatients.indexDate BETWEEN @startDate AND @endDate
							) initital
						LEFT JOIN 
							(
								SELECT 
									enc.[date],
									enc.patientid,
									MIN(CONVERT(VARCHAR(2), h.[value])) AS [value]
								FROM 
									structhpi h
								INNER JOIN 
									enc
										ON enc.encounterID = h.encounterId
								INNER JOIN 
									users u
										ON enc.patientID = u.[uid]
								WHERE 
									(
										catId = 257803
										AND itemId = 12325
										AND detailId = 15
									)
									and enc.date between DATEADD(DAY, -60, DATEADD(MONTH, 12, @startDate)) and DATEADD(DAY, 60, DATEADD(MONTH, 12, @endDate))
									AND CAST(h.[value] AS VARCHAR(MAX)) IS NOT NULL
									AND CAST(h.[value] AS VARCHAR(MAX)) <> ''
									--AND CAST(CONVERT(VARCHAR(2), value) AS int) > 9
								GROUP BY 
									patientID,
									enc.[date]
							) Follow
								ON Follow.patientID = initital.patientID
									AND follow.[date] BETWEEN DATEADD(DAY, - 60, DATEADD(MONTH, 12, initital.[date]))
									AND DATEADD(DAY, 60, DATEADD(MONTH, 12, initital.[date]))
							GROUP BY 
								initital.patientID,
								initital.[date]
					) PHQFollowDate
				LEFT JOIN 
					(
						SELECT 
							enc.[date],
							enc.patientid,
							MIN(CONVERT(VARCHAR(2), h.[value])) AS [value]
						FROM 
							structhpi h
						INNER JOIN 
							enc
								ON enc.encounterID = h.encounterId
						INNER JOIN 
							users u
								ON enc.patientID = u.[uid]
						WHERE 
							(
								catId = 257803
								AND itemId = 12325
								AND detailId = 15
							)
							and enc.date between DATEADD(DAY, -60, DATEADD(MONTH, 12, @startDate)) and DATEADD(DAY, 60, DATEADD(MONTH, 12, @endDate))
							--AND CAST(CONVERT(VARCHAR(2), value) AS int) > 9
						GROUP BY 
							patientID,
							enc.[date]
					) PHQFollowValue
						ON PHQFollowDate.followDate = PHQFollowValue.[date]
							AND PHQFollowDate.patientID = PHQFollowValue.patientID
		) PHQ
			ON PHQ.patientID = u.[uid]
		LEFT JOIN 
			(
				SELECT DISTINCT 
					pl.patientId,
					MIN
						(
							CAST
								(
									CASE 
										WHEN 
											(
												pl.AddedDate IS NULL
												OR pl.AddedDate = ''
											)
											AND pl.encounterId != 0
											THEN CONVERT(VARCHAR(19), enc.DATE, 101)
										WHEN
											(
												pl.AddedDate IS NULL
												OR pl.AddedDate = ''
											)
											AND pl.encounterId = 0
											THEN CONVERT(VARCHAR(19), pl.logdate, 101)
										ELSE CAST(pl.AddedDate AS VARCHAR(255))
									END AS DATE
									)
						) AS [AddedDate]
				FROM 
					problemlist pl
				INNER JOIN 
					itemdetail id
						ON id.itemID = pl.asmtId
							AND id.propID = 13
				LEFT JOIN 
					enc
						ON enc.encounterID = pl.encounterId
							AND pl.encounterId != 0
				WHERE 
					id.[value] IN 
								(
									'F30.10','F30.11','F30.12','F30.13',
									'F30.2','F30.3','F30.4','F30.8',
									'F30.9','F31.0','F31.10','F31.11',
									'F31.12','F31.13','F31.2','F31.30',
									'F31.31','F31.32','F31.4','F31.5',
									'F31.60','F31.61','F31.62','F31.63',
									'F31.64','F31.70','F31.71','F31.72',
									'F31.73','F31.74','F31.75','F31.76',
									'F31.77','F31.78','F31.81','F31.89',
									'F31.9'
								)
					AND pl.deleteFlag = 0
					AND pl.AddedDate <= @endDate
				GROUP BY 
					pl.patientId
			) Bipolar
				ON Bipolar.patientId = u.uid
			--END Bipolar Exclusion
			--START Personality Disorder Exclusion
		LEFT JOIN 
			(
				SELECT DISTINCT 
					pl.patientId,
					MIN
						(
							CAST
								(
									CASE 
										WHEN 
											(
												pl.AddedDate IS NULL
												OR pl.AddedDate = ''
											)
											AND pl.encounterId != 0
											THEN CONVERT(VARCHAR(19), enc.[date], 101)
										WHEN 
											(
												pl.AddedDate IS NULL
												OR pl.AddedDate = ''
											)
											AND pl.encounterId = 0
											THEN CONVERT(VARCHAR(19), pl.logdate, 101)
										ELSE CAST(pl.AddedDate AS VARCHAR(255))
									END AS DATE
								)
						) AS [AddedDate]
				FROM 
					problemlist pl
				INNER JOIN 
					itemdetail id
						ON id.itemID = pl.asmtId
							AND id.propID = 13
				LEFT JOIN 
					enc
						ON enc.encounterID = pl.encounterId
							AND pl.encounterId != 0
				WHERE 
					id.[value] IN 
							(
								'F21','F34.0','F60.3','F60.4','F68.10','F68.11','F68.12','F68.13',
								'301.13','301.50','301.51','301.83',					
								--Added for 2020--
								'F20.0','F20.1','F20.2','F20.3','F20.5','F20.81','F20.89','F20.9','F21','F23','F25.0','F25.1',
								'F25.8','F25.9','F28','F29','295.00','295.01','295.02','295.03','295.04','295.05','295.10',
								'295.11','295.12','295.13','295.14','295.15','295.20','295.21','295.22','295.23','295.24',
								'295.25','295.30','295.31','295.32','295.33','295.34','295.35','295.40','295.41','295.42','295.43',
								'295.44','295.45','295.50','295.51','295.52','295.53','295.54','295.55','295.60','295.61','295.62',
								'295.63','295.64','295.65','295.70','295.71','295.72','295.73','295.74','295.75','295.80','295.81',
								'295.82','295.83','295.84','295.85','295.90','295.91','295.92','295.93','295.94','295.95','298.0',
								'298.1','298.4','298.8','298.9','F84.0','F84.3','F84.8','F84.9','299.00','299.01','299.10','299.11',
								'299.80','299.81','299.90','299.91'
								--Added for 2020--

							)
					AND pl.deleteFlag = 0
					AND pl.AddedDate <= @endDate
				GROUP BY 
					pl.patientId
			) Personality
				ON Personality.patientId = u.[uid]
		LEFT JOIN 
			(
				SELECT DISTINCT 
					pad.ptid
				FROM 
					pt_adv_directives pad
				WHERE 
					pad.CODE = 'HOSPICE'
					AND pad.delflag = 0
					AND pad.MDate <= CAST(@endDate AS DATE)
			) Hospice
				ON Hospice.PtId = u.uid
--START Paliative Filter added 2020
		left join (
			Select
				DISTINCT
				i.PatientId
			FROM
				edi_invoice i
				inner join edi_inv_diagnosis d on d.InvoiceId = i.Id
				inner join itemdetail id on id.itemID = d.itemID and id.propID = 13
			WHERE
				i.ServiceDt between @startDate and @endDate
				AND id.value = 'Z51.5' --added for 2020
			GROUP BY i.PatientId
		) Paliative on Paliative.PatientId = u.uid
--END Paliative Filter added 2020
	WHERE 
		PHQ.initDate IS NOT NULL
		AND u.delFlag = 0
		AND u.UserType = 3
		AND 
		(
			p.deceased = 0
			OR 
			(
				p.deceased = 1
				AND ISDATE(p.deceasedDate) = 1
				AND CAST(p.deceasedDate AS DATE) > @endDate
			)
		)
		AND u.[status] = 0
		and u.ptDob <= DATEADD(YEAR, -5, @startDate)
		and u.ptDob >= DATEADD(YEAR, -18, @startDate)
		AND Hospice.ptId IS NULL
		AND Personality.patientId IS NULL
		AND Bipolar.patientId IS NULL
		AND indexedPatients.indexDate BETWEEN @startDate AND @endDate
		AND Paliative.PatientId is null
		and (f.[Name] not like '%URGENT%' and f.[Name] not like '%express%' and f.[Name] not like '%dexascan%' and f.[Name] not like '%echo%')

	) Main
inner join(
Select 
	CONVERT(date, @startDate) [Indexstart]
	,CONVERT(date, @endDate) [IndexEnd]
	,CONVERT(date, @startDate1) [Startdate]
	,CONVERT(date, @endDate1) [Enddate]
	,CONVERT(varchar(19),CONVERT(date, @startDate1),101)+' - '+CONVERT(varchar(19),CONVERT(date, @endDate1),101) as [Date Span]
	,CAST(
	ROUND(
	CAST(COUNT (
		CASE
			WHEN
				[Latest PHQ Score] <> '' and [Latest PHQ Score] < 5
					THEN [Patient Account Number]
		END) AS Decimal)
	/
	COUNT ([Patient Account Number])
	,2) 
		AS DECIMAL (5,2)) [MaxDate]
	
FROM 
	(
		SELECT 
			f.[Name] AS [Clinic],
			doc.ulname + ', ' + doc.ufname AS [Provider],
			p.ControlNo AS [Patient Account Number],
			u.ulname AS [Patient Last Name],
			u.ufname AS [Patient First Name],
			CONVERT(VARCHAR(19), PHQ.initDate, 101) AS [Initial PHQ],
			CONVERT(VARCHAR(19), PHQ.followDate, 101) AS [Follow Up Date],
			CASE 
				WHEN PHQ.[value] IS NULL
					THEN ''
				ELSE PHQ.[value]
				END AS [Latest PHQ Score]
		FROM 
			@IndexedPatients indexedPatients
		INNER JOIN 
			patients p
				ON p.ControlNo = indexedPatients.patientId
		INNER JOIN 
			users u
				ON u.[uid] = p.pid
		LEFT JOIN 
			users doc
				ON doc.[uid] = p.doctorId
		LEFT JOIN 
			edi_facilities f
				ON f.Id = doc.primaryservicelocation
		LEFT JOIN 
			edi_facilities patfac
				ON patfac.Id = u.primaryservicelocation
		LEFT JOIN 
			(
				SELECT 
					PHQFollowDate.patientID,
					PHQFollowDate.initDate,
					PHQFollowDate.followDate,
					PHQFollowValue.[value]
				FROM 
					(
						SELECT 
							initital.patientID,
							initital.[date] AS [initDate],
							MAX(Follow.[date]) AS [followDate]
						FROM 
							(
								SELECT 
									indexedPatients.indexDate AS [DATE],
									p.pid AS [patientID]
								FROM 
									@IndexedPatients indexedPatients
								INNER JOIN 
									patients p
										ON p.ControlNo = indexedPatients.patientId
											AND indexedPatients.indexDate BETWEEN @startDate AND @endDate
							) initital
						LEFT JOIN 
							(
								SELECT 
									enc.[date],
									enc.patientid,
									MIN(CONVERT(VARCHAR(2), h.[value])) AS [value]
								FROM 
									structhpi h
								INNER JOIN 
									enc
										ON enc.encounterID = h.encounterId
								INNER JOIN 
									users u
										ON enc.patientID = u.[uid]
								WHERE 
									(
										catId = 257803
										AND itemId = 12325
										AND detailId = 15
									)
									and enc.date between DATEADD(DAY, -60, DATEADD(MONTH, 12, @startDate)) and DATEADD(DAY, 60, DATEADD(MONTH, 12, @endDate))
									AND CAST(h.[value] AS VARCHAR(MAX)) IS NOT NULL
									AND CAST(h.[value] AS VARCHAR(MAX)) <> ''
									--AND CAST(CONVERT(VARCHAR(2), value) AS int) > 9
								GROUP BY 
									patientID,
									enc.[date]
							) Follow
								ON Follow.patientID = initital.patientID
									AND follow.[date] BETWEEN DATEADD(DAY, - 60, DATEADD(MONTH, 12, initital.[date]))
									AND DATEADD(DAY, 60, DATEADD(MONTH, 12, initital.[date]))
							GROUP BY 
								initital.patientID,
								initital.[date]
					) PHQFollowDate
				LEFT JOIN 
					(
						SELECT 
							enc.[date],
							enc.patientid,
							MIN(CONVERT(VARCHAR(2), h.[value])) AS [value]
						FROM 
							structhpi h
						INNER JOIN 
							enc
								ON enc.encounterID = h.encounterId
						INNER JOIN 
							users u
								ON enc.patientID = u.[uid]
						WHERE 
							(
								catId = 257803
								AND itemId = 12325
								AND detailId = 15
							)
							and enc.date between DATEADD(DAY, -60, DATEADD(MONTH, 12, @startDate)) and DATEADD(DAY, 60, DATEADD(MONTH, 12, @endDate))
							--AND CAST(CONVERT(VARCHAR(2), value) AS int) > 9
						GROUP BY 
							patientID,
							enc.[date]
					) PHQFollowValue
						ON PHQFollowDate.followDate = PHQFollowValue.[date]
							AND PHQFollowDate.patientID = PHQFollowValue.patientID
		) PHQ
			ON PHQ.patientID = u.[uid]
		LEFT JOIN 
			(
				SELECT DISTINCT 
					pl.patientId,
					MIN
						(
							CAST
								(
									CASE 
										WHEN 
											(
												pl.AddedDate IS NULL
												OR pl.AddedDate = ''
											)
											AND pl.encounterId != 0
											THEN CONVERT(VARCHAR(19), enc.DATE, 101)
										WHEN
											(
												pl.AddedDate IS NULL
												OR pl.AddedDate = ''
											)
											AND pl.encounterId = 0
											THEN CONVERT(VARCHAR(19), pl.logdate, 101)
										ELSE CAST(pl.AddedDate AS VARCHAR(255))
									END AS DATE
									)
						) AS [AddedDate]
				FROM 
					problemlist pl
				INNER JOIN 
					itemdetail id
						ON id.itemID = pl.asmtId
							AND id.propID = 13
				LEFT JOIN 
					enc
						ON enc.encounterID = pl.encounterId
							AND pl.encounterId != 0
				WHERE 
					id.[value] IN 
								(
									'F30.10','F30.11','F30.12','F30.13',
									'F30.2','F30.3','F30.4','F30.8',
									'F30.9','F31.0','F31.10','F31.11',
									'F31.12','F31.13','F31.2','F31.30',
									'F31.31','F31.32','F31.4','F31.5',
									'F31.60','F31.61','F31.62','F31.63',
									'F31.64','F31.70','F31.71','F31.72',
									'F31.73','F31.74','F31.75','F31.76',
									'F31.77','F31.78','F31.81','F31.89',
									'F31.9'
								)
					AND pl.deleteFlag = 0
					AND pl.AddedDate <= @endDate
				GROUP BY 
					pl.patientId
			) Bipolar
				ON Bipolar.patientId = u.uid
			--END Bipolar Exclusion
			--START Personality Disorder Exclusion
		LEFT JOIN 
			(
				SELECT DISTINCT 
					pl.patientId,
					MIN
						(
							CAST
								(
									CASE 
										WHEN 
											(
												pl.AddedDate IS NULL
												OR pl.AddedDate = ''
											)
											AND pl.encounterId != 0
											THEN CONVERT(VARCHAR(19), enc.[date], 101)
										WHEN 
											(
												pl.AddedDate IS NULL
												OR pl.AddedDate = ''
											)
											AND pl.encounterId = 0
											THEN CONVERT(VARCHAR(19), pl.logdate, 101)
										ELSE CAST(pl.AddedDate AS VARCHAR(255))
									END AS DATE
								)
						) AS [AddedDate]
				FROM 
					problemlist pl
				INNER JOIN 
					itemdetail id
						ON id.itemID = pl.asmtId
							AND id.propID = 13
				LEFT JOIN 
					enc
						ON enc.encounterID = pl.encounterId
							AND pl.encounterId != 0
				WHERE 
					id.[value] IN 
							(
								'F21','F34.0','F60.3','F60.4','F68.10','F68.11','F68.12','F68.13',
								'301.13','301.50','301.51','301.83',					
								--Added for 2020--
								'F20.0','F20.1','F20.2','F20.3','F20.5','F20.81','F20.89','F20.9','F21','F23','F25.0','F25.1',
								'F25.8','F25.9','F28','F29','295.00','295.01','295.02','295.03','295.04','295.05','295.10',
								'295.11','295.12','295.13','295.14','295.15','295.20','295.21','295.22','295.23','295.24',
								'295.25','295.30','295.31','295.32','295.33','295.34','295.35','295.40','295.41','295.42','295.43',
								'295.44','295.45','295.50','295.51','295.52','295.53','295.54','295.55','295.60','295.61','295.62',
								'295.63','295.64','295.65','295.70','295.71','295.72','295.73','295.74','295.75','295.80','295.81',
								'295.82','295.83','295.84','295.85','295.90','295.91','295.92','295.93','295.94','295.95','298.0',
								'298.1','298.4','298.8','298.9','F84.0','F84.3','F84.8','F84.9','299.00','299.01','299.10','299.11',
								'299.80','299.81','299.90','299.91'
								--Added for 2020--

							)
					AND pl.deleteFlag = 0
					AND pl.AddedDate <= @endDate
				GROUP BY 
					pl.patientId
			) Personality
				ON Personality.patientId = u.[uid]
		LEFT JOIN 
			(
				SELECT DISTINCT 
					pad.ptid
				FROM 
					pt_adv_directives pad
				WHERE 
					pad.CODE = 'HOSPICE'
					AND pad.delflag = 0
					AND pad.MDate <= CAST(@endDate AS DATE)
			) Hospice
				ON Hospice.PtId = u.uid
--START Paliative Filter added 2020
		left join (
			Select
				DISTINCT
				i.PatientId
			FROM
				edi_invoice i
				inner join edi_inv_diagnosis d on d.InvoiceId = i.Id
				inner join itemdetail id on id.itemID = d.itemID and id.propID = 13
			WHERE
				i.ServiceDt between @startDate and @endDate
				AND id.value = 'Z51.5' --added for 2020
			GROUP BY i.PatientId
		) Paliative on Paliative.PatientId = u.uid
--END Paliative Filter added 2020
	WHERE 
		PHQ.initDate IS NOT NULL
		AND u.delFlag = 0
		AND u.UserType = 3
		AND 
		(
			p.deceased = 0
			OR 
			(
				p.deceased = 1
				AND ISDATE(p.deceasedDate) = 1
				AND CAST(p.deceasedDate AS DATE) > @endDate
			)
		)
		AND u.[status] = 0
		and u.ptDob <= DATEADD(YEAR, -5, @startDate)
		and u.ptDob >= DATEADD(YEAR, -18, @startDate)
		AND Hospice.ptId IS NULL
		AND Personality.patientId IS NULL
		AND Bipolar.patientId IS NULL
		AND indexedPatients.indexDate BETWEEN @startDate AND @endDate
		AND Paliative.PatientId is null
		and (f.[Name] not like '%URGENT%' and f.[Name] not like '%express%' and f.[Name] not like '%dexascan%' and f.[Name] not like '%echo%')

	) Main
)org on org.startdate = @startDate1
GROUP BY 
	Clinic)  PatientMaxDates
PIVOT(
	max(MaxDate)
FOR   
[ItemRename]   
    IN ([ENTIRA COMO ROSEVILLE],[ENTIRA EAST SIDE CLINIC],[ENTIRA HIGHLAND],[ENTIRA INVER GROVE HEIGHTS],[ENTIRA NORTH ST PAUL],[ENTIRA SHOREVIEW],[ENTIRA VADNAIS HEIGHTS],[ENTIRA HUGO]
	,[ENTIRA WEST ST PAUL CLINIC],[ENTIRA WOODBURY])
) AS TestPivot


option(maxdop 0 , recompile)