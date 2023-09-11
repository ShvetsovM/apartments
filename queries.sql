-- Первая запись в таблице Apartments, созданной с помощью веб сервиса WebScraper и сайта avito:
SELECT TOP 1 *
FROM Apartments

--Таблица Metro_stations:
SELECT TOP 5 *
FROM Metro_stations;

--Для исключения дублирования объявлений удалил дубликаты записей с помощью группировки по ссылке:
DELETE FROM Apartments
WHERE link IN (SELECT link FROM Apartments GROUP BY link HAVING COUNT(*) > 1);

--Создание новых столбцов и запись данных:
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
	REPLACE(SUBSTRING(overview, CHARINDEX(',', overview)+2, CHARINDEX('м'+NCHAR(178), overview)-CHARINDEX(',', overview)-3),',', '.') AS area,
	SUBSTRING(overview, charindex('м'+NCHAR(178), overview)+4, CHARINDEX('/', overview)-(charindex('м'+NCHAR(178), overview)+4)) AS apart_floor,
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

--Информация о станции метро и ее удаленности находится в одном столбце.
--Создание новых столбцов и запись данных:
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
		WHEN metro_time LIKE '%от' + NCHAR(160) + '[0-9]%' OR metro_time LIKE '%до' + NCHAR(160) + '[0-9]%' 
			THEN SUBSTRING(metro_time,1,PATINDEX('%[0-9]%', metro_time)-4)
			ELSE metro_time
	END AS metro_station,
    CASE 
        WHEN metro_time LIKE '%[0-9]' + NCHAR(8211) + '[0-9]%' 
			THEN ROUND(
            (CAST(SUBSTRING(metro_time, PATINDEX('%[0-9]%', metro_time), PATINDEX('%[0-9]' + NCHAR(8211) + '[0-9]%', metro_time) - PATINDEX('%[0-9]%', metro_time) + 1) AS FLOAT)
            + CAST(SUBSTRING(metro_time, CHARINDEX(NCHAR(8211), metro_time) + 1, LEN(metro_time) - 5 - CHARINDEX(NCHAR(8211), metro_time)) AS FLOAT)) / 2, 1)
        WHEN metro_time LIKE '%от' + NCHAR(160) + '[0-9]%' OR metro_time LIKE '%до' + NCHAR(160) + '[0-9]%' 
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

--Так как одна станция может находитсья на двух линиях метро, нужно удалить дубликаты:
WITH cte AS (
    SELECT *,
           ROW_NUMBER() OVER (PARTITION BY metro_station ORDER BY metro_station_id) AS rn
    FROM Metro_stations
)
DELETE FROM Metro_stations
WHERE metro_station_id IN (
    SELECT metro_station_id FROM cte WHERE rn > 1
);

--Сравнение средней арендной платы студий и однокомнатных квартир:
SELECT rooms, COUNT(*) AS offers_amount, AVG(rent_new) AS average_rent
FROM Apartments
GROUP BY rooms
ORDER BY average_rent DESC

--Сравнение средней арендной платы квартир находящихся на первом или последнем этаже и средней арендной платы квартир на средних этажах:
SELECT 'First and top floor Apartments' AS category, COUNT(*) AS offers_amount, AVG(rent_new) AS average_price
FROM Apartments
WHERE apart_floor = 1 OR apart_floor = total_floor 
UNION
SELECT 'Middle-floor Apartments', COUNT(*), AVG(rent_new)
FROM Apartments
WHERE apart_floor <> 1 AND apart_floor <> total_floor;

--Сравнение средней арендной платы квартир с площадью ниже среднего и выше среднего:
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

--Сравнение средней арендной платы квартир, от которых пешее время до метро ниже среднего и выше среднего:
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

--Сравнение округов по количеству объявлений
SELECT adm_area, COUNT(*) AS offers_amount, ROUND(CAST(COUNT(*) AS FLOAT) / SUM(COUNT(*)) OVER () * 100,2) AS "percentage"
FROM Apartments AS ap
INNER JOIN Metro_stations AS ms
    ON ap.metro_station = ms.metro_station
GROUP BY adm_area
ORDER BY COUNT(*) DESC;

--Сравнение средней арендной платы квартир в разных административных округах Москвы:
SELECT adm_area, COUNT(*) AS offers_amount, AVG(rent_new) AS average_rent
FROM Apartments AS ap
INNER JOIN Metro_stations AS ms
    ON ap.metro_station = ms.metro_station
GROUP BY adm_area
ORDER BY AVG(rent_new) DESC;

--Сравнение средней арендной платы квартир в разных районах Москвы:
SELECT district, COUNT(*) AS offers_amount, AVG(rent_new) AS average_rent
FROM Apartments AS ap
INNER JOIN Metro_stations AS ms
    ON ap.metro_station = ms.metro_station
GROUP BY district
HAVING COUNT(*) > 10
ORDER BY AVG(rent_new) DESC;

--Сравнение средней арендной платы квартир, располагающихся вблизи станций метро разных линий:
SELECT line, COUNT(*) AS offers_amount, AVG(rent_new) AS average_rent
FROM Apartments AS ap
INNER JOIN Metro_stations AS ms
    ON ap.metro_station = ms.metro_station
GROUP BY line
ORDER BY AVG(rent_new) DESC;
