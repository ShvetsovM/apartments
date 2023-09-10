-- ������ ������ � ������� Apartments, ��������� � ������� ��� ������� WebScraper � ����� avito:
SELECT TOP 1 *
FROM Apartments

--������� Metro_stations:
SELECT TOP 5 *
FROM Metro_stations;

--��� ���������� ������������ ���������� ������ ��������� ������� � ������� ����������� �� ������:
DELETE FROM Apartments
WHERE link IN (SELECT link FROM Apartments GROUP BY link HAVING COUNT(*) > 1);

--�������� ����� �������� � ������ ������:
ALTER TABLE Apartments
ADD rooms varchar(20);

ALTER TABLE Apartments
ADD area float;

ALTER TABLE Apartments
ADD apart_floor int;

ALTER TABLE Apartments
ADD total_floor int;

ALTER TABLE Apartments
ADD rent_new int;

WITH cte AS(
SELECT
	apartment_id,
    SUBSTRING(overview, 1, CHARINDEX(',', overview)-1) AS rooms,
	REPLACE(SUBSTRING(overview, CHARINDEX(',', overview)+2, CHARINDEX('�'+NCHAR(178), overview)-CHARINDEX(',', overview)-3),',', '.') AS area,
	SUBSTRING(overview, charindex('�'+NCHAR(178), overview)+4, CHARINDEX('/', overview)-(charindex('�'+NCHAR(178), overview)+4)) AS apart_floor,
	SUBSTRING(overview, CHARINDEX('/',overview)+1,len(overview)-CHARINDEX('/',overview)-4)as total_floor,
	REPLACE((SUBSTRING(rent, PATINDEX('[0-9]', rent), len(rent)-PATINDEX('[0-9]', rent)-9)),NCHAR(160),'') AS rent_new
FROM Apartments
)

UPDATE Apartments 
SET rooms = cte.rooms,
    area = cte.area,
    apart_floor = cte.apart_floor,
    total_floor = cte.total_floor,
	rent_new = cte.rent_new
FROM Apartments
INNER JOIN cte ON Apartments.apartment_id = cte.apartment_id;

SELECT top 4 apartment_id, overview, rooms, area, apart_floor, total_floor, rent, rent_new
FROM Apartments

--���������� � ������� ����� � �� ����������� ��������� � ����� �������.
--�������� ����� �������� � ������ ������:
ALTER TABLE Apartments
ADD metro_station varchar(40);

ALTER TABLE Apartments
ADD time_to_metro float;

WITH cte AS(
SELECT 
	apartment_id,
    metro_time,
	CASE 
		WHEN metro_time LIKE '%[0-9]' + NCHAR(8211) + '[0-9]%' 
			THEN SUBSTRING(metro_time,1,PATINDEX('%[0-9]%', metro_time)-1)
		WHEN metro_time LIKE '%��' + NCHAR(160) + '[0-9]%' OR metro_time LIKE '%��' + NCHAR(160) + '[0-9]%' 
			THEN SUBSTRING(metro_time,1,PATINDEX('%[0-9]%', metro_time)-4)
			ELSE metro_time
	END AS metro_station,
    CASE 
        WHEN metro_time LIKE '%[0-9]' + NCHAR(8211) + '[0-9]%' 
			THEN ROUND(
            (CAST(SUBSTRING(metro_time, PATINDEX('%[0-9]%', metro_time), PATINDEX('%[0-9]' + NCHAR(8211) + '[0-9]%', metro_time) - PATINDEX('%[0-9]%', metro_time) + 1) AS FLOAT)
            + CAST(SUBSTRING(metro_time, CHARINDEX(NCHAR(8211), metro_time) + 1, LEN(metro_time) - 5 - CHARINDEX(NCHAR(8211), metro_time)) AS FLOAT)) / 2, 1)
        WHEN metro_time LIKE '%��' + NCHAR(160) + '[0-9]%' OR metro_time LIKE '%��' + NCHAR(160) + '[0-9]%' 
			THEN SUBSTRING(metro_time, PATINDEX('%[0-9]%', metro_time), LEN(metro_time) - 4 - PATINDEX('%[0-9]%', metro_time))
        ELSE NULL
    END AS time_to_metro 
FROM Apartments)

UPDATE Apartments
SET metro_station = cte.metro_station,
	time_to_metro = cte.time_to_metro 
FROM Apartments
INNER JOIN cte ON Apartments.apartment_id = cte.apartment_id;

SELECT apartment_id, metro_time, metro_station, time_to_metro 
FROM Apartments
WHERE apartment_id IN ('1694098787-1', '1694098787-16', '1694098787-18', '1694098787-25');

--��� ��� ���� ������� ����� ���������� �� ���� ������ �����, ����� ������� ���������:
WITH cte AS (
    SELECT *,
           ROW_NUMBER() OVER (PARTITION BY metro_station ORDER BY metro_station_id) AS rn
    FROM Metro_stations
)
DELETE FROM Metro_stations
WHERE metro_station_id IN (
    SELECT metro_station_id FROM cte WHERE rn > 1
);

--��������� ������� �������� ����� ������ � ������������� �������:
SELECT rooms, COUNT(*) AS offers_amount, AVG(rent_new) AS average_rent
FROM Apartments
GROUP BY rooms
ORDER BY average_rent DESC

--��������� ������� �������� ����� ������� ����������� �� ������ ��� ��������� ����� � ������� �������� ����� ������� �� ������� ������:
SELECT 'First and top floor Apartments' AS category, COUNT(*) AS offers_amount, AVG(rent_new) AS average_price
FROM Apartments
WHERE apart_floor = 1 OR apart_floor = total_floor 
UNION
SELECT 'Middle-floor Apartments', COUNT(*), AVG(rent_new)
FROM Apartments
WHERE apart_floor <> 1 AND apart_floor <> total_floor;

--��������� ������� �������� ����� ������� � �������� ���� �������� � ���� ��������:
WITH cte AS (
    SELECT AVG(area) AS average_area
    FROM Apartments
)
SELECT 
    CASE 
        WHEN area > average_area THEN 'Above Average'
        ELSE 'Below Average'
    END AS area_category, 
    COUNT(*) AS offers_amount,
    AVG(rent_new) AS average_rent
FROM Apartments
CROSS JOIN cte
GROUP BY 
    CASE 
        WHEN area > average_area THEN 'Above Average'
        ELSE 'Below Average'
    END;

--��������� ������� �������� ����� �������, �� ������� ����� ����� �� ����� ���� �������� � ���� ��������:
WITH cte AS (
    SELECT AVG(time_to_metro) AS average_time
    FROM Apartments
)
SELECT 
    CASE 
        WHEN time_to_metro > average_time THEN 'Above Average'
        ELSE 'Below Average'
    END AS time_category, 
    COUNT(*) AS offers_amount,
    AVG(rent_new) AS average_rent
FROM Apartments
CROSS JOIN cte
WHERE time_to_metro IS NOT NULL
GROUP BY 
    CASE 
        WHEN time_to_metro > average_time THEN 'Above Average'
        ELSE 'Below Average'
    END;

--��������� ������� �������� ����� ������� � ������ ���������������� ������� ������:
SELECT adm_area, COUNT(*) AS offers_amount, AVG(rent_new) AS average_rent
FROM Apartments AS ap
INNER JOIN Metro_stations AS ms
    ON ap.metro_station = ms.metro_station
GROUP BY adm_area
ORDER BY AVG(rent_new) DESC;

--��������� ������� �������� ����� ������� � ������ ������� ������:
SELECT district, COUNT(*) AS offers_amount, AVG(rent_new) AS average_rent
FROM Apartments AS ap
INNER JOIN Metro_stations AS ms
    ON ap.metro_station = ms.metro_station
GROUP BY district
HAVING COUNT(*) > 10
ORDER BY AVG(rent_new) DESC;

--��������� ������� �������� ����� �������, ��������������� ������ ������� ����� ������ �����:
SELECT line, COUNT(*) AS offers_amount, AVG(rent_new) AS average_rent
FROM Apartments AS ap
INNER JOIN Metro_stations AS ms
    ON ap.metro_station = ms.metro_station
GROUP BY line
ORDER BY AVG(rent_new) DESC;