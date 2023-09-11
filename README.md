# Аренда квартир
## Описание проекта 
В Москве выбор жилья становится всё более важной задачей, особенно для студентов, которые ищут подходящее жильё, учитывая ограниченный бюджет и специфические требования.

В данном проекте я проведу анализ объявлений на сайте **avito** о сдаче квартир, которые наилучшим образом соответствуют потребностям студентов в Москве.

## Задачи 

Целью моего проекта является подтвердить или опровергнуть некоторые гипотезы, а также ответить на интересующие меня вопросы с помощью анализа данных с использованием SQL-запросов:

1. Арендная плата за студии дороже чем за однокомнатные квартиры.
2. Квартиры на первом или последнем этаже имеют меньшую арендную плату.
3. Площадь однокомнатных квартир и студий несильно влияет на арендную плату.
4. Пешее время имеет сильное виляние на формирование арендной платы.
5. Какие округа самые дорогие и популярные? 
6. Какие районы самые дорогие и популярные? 
7. Как расположение рядом с определенной линией метро повлияет на цену? 

## Источник данных

### Таблица с объявлениями
Источником данных я выбрал сайт **avito**, и провел поиск объявлений о сдачи в аренду квартир с заданными критериями: 
- Количество комнат: Студия, 1 комната
- Арендная плата: до 100 тыс.
- Тип жилья: Квартира
- Мебель: Кухня, спальные места, хранение одежды
- Техника: Холодильник, плита, стиральная машина
- Интернет и ТВ: Wi-Fi
***
С помощью расширения **Web Scraper** создал таблицу объявлений со столбцами: 
- apartment_id (уникальный иденификатор объявления)
- overview	(название объявления)
- rent	(арендная плата)
- metro_time	(станция метро и время пути до него)
- address	(адрес)
- description	(описание)
- link (ссылка на объявление)
  
Отредактировал таблицу в **excel** и импортировал в **SSMS**, дав название **Apartments**.

***

Первая запись в таблице **Apartments**, созданной с помощью веб сервиса **WebScraper** и сайта **avito**:

**Запрос:**

````sql
SELECT TOP 1 *
FROM Apartments
````
**Результат:**

| apartment_id    | overview                             | rent            | metro_time              | address        | description                                                                                                                                              | link                                                                                 |
|-----------------|--------------------------------------------|---------------------|--------------------------|----------------------|--------------------------------------------------------------------------------------------------------------------------------------------------------------|--------------------------------------------------------------------------------------------------|
| 1694098787-1    | 1-к. квартира, 38 м², 4/5 эт.              | 38 000 ₽ в месяц    | Бульвар Рокоссовского 11–15 мин. | Бойцовая ул., 17к1   | Сдается квартира (собственник)... *(Сокращено для читабельности) | https://www.avito.ru/moskva/kvartiry/1-k._kvartira_38m_45et._1127526878 |

***
### Таблица с информацией о станциях метро

Для дальнейшей работы мне понадобится таблица, которая будет содержать информацию о станции метро для анализа объявлений по административным округам, районам и линиям метро.

Подходящую таблицу я нашел на сайте data.mos.ru - **"Станции Московского метрополитена"**

Отредактировал ее в excel и импортировал в SSMS, дав название **Metro_stations**
***
Таблица **Metro_stations**:

**Запрос:**

````sql
SELECT TOP 5 *
FROM Metro_stations;
````

**Результат:**

| metro_station_id | metro_station   | line                    | adm_area                          | district                   |
|------------------|-----------------|-------------------------|-----------------------------------|-----------------------------|
| 1                | Третьяковская   | Калининская линия       | Центральный административный округ | район Замоскворечье       |
| 2                | Медведково      | Калужско-Рижская линия | Северо-Восточный административный округ | район Северное Медведково |
| 3                | Первомайская    | Арбатско-Покровская линия | Восточный административный округ | район Измайлово           |
| 4                | Калужская       | Калужско-Рижская линия | Юго-Западный административный округ | Обручевский район         |
| 5                | Каховская       | Большая кольцевая линия | Юго-Западный административный округ | район Зюзино              |


***
В исходных таблицах есть несколько проблем, которые создадут проблемы для дальнейшей работы. Проведу преобразование данных.

# Подготовка данных

## * **Apartments** 


## Удаление дубликатов

Для исключения дублирования объявлений удалил дубликаты записей с помощью группировки по ссылке:

**Запрос:**

````sql
DELETE FROM Apartments
WHERE link IN (SELECT link FROM Apartments GROUP BY link HAVING COUNT(*) > 1);
````
## Название объявления

Информация о комнатности квартиры, площади, этаже и общем количестве этажей находится в одном столбце overview. А также информация об арендной плате имеет непригодный для вычислений формат. 

Создание новых столбцов и запись данных:

**Запрос:**
   
````sql
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
````

**Результат:**

| apartment_id    | overview                             | rooms           | area | apart_floor | total_floor | rent                | rent_new |
|-----------------|-------------------------------------|-----------------|------|-------------|-------------|---------------------|----------|
| 1694098787-1    | 1-к. квартира, 38 м², 4/5 эт.       | 1-к. квартира   | 38   | 4           | 5           | 38 000 ₽ в месяц   | 38000    |
| 1694098787-10   | 1-к. квартира, 44 м², 3/14 эт.      | 1-к. квартира   | 44   | 3           | 14          | 65 000 ₽ в месяц   | 65000    |
| 1694098787-11   | 1-к. квартира, 14 м², 1/12 эт.      | 1-к. квартира   | 14   | 1           | 12          | 37 500 ₽ в месяц   | 37500    |
| 1694098787-12   | Квартира-студия, 50 м², 6/9 эт.     | Квартира-студия | 50   | 6           | 9           | 25 000 ₽ в месяц   | 25000    |

<details>
<summary>Пометка</summary>
В таблице Apartments появились новые столбцы:

- rooms (комнатность)
- area (площадь)
- apart_floor (этаж)
- total_floor (всего этажей)
- new_rent (арендная плата)

</details>

***

## Станция метро и путь до нее

Информация о станции метро и ее удаленности находится в одном столбце.

Создание новых столбцов и запись данных:

**Запрос:**

````sql
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
````

**Результат:**

| apartment_id    | metro_time                     | metro_station         | time_to_metro |
|-----------------|--------------------------------|-----------------------|---------------|
| 1694098787-1    | Бульвар Рокоссовского 11–15 мин. | Бульвар Рокоссовского | 13            |
| 1694098787-16   | Аминьевская 21–30 мин.          | Аминьевская           | 25,5          |
| 1694098787-18   | Новогиреево до 5 мин.           | Новогиреево           | 5             |
| 1694098787-25   | Народное Ополчение от 31 мин.   | Народное Ополчение     | 31            |

<details>
<summary>Пометка</summary>

В таблице Apartments появились новые столбцы:

- metro_station (ближайшая станция метро)
- time_ro_metro (время пути до метро)

  *Если время указано в формате "5-10 мин.", то значение time_to_metro будет равно среднему времени (7.5). 
  
  Если в формате "от 5 мин." или "до 5 мин." то будет присвоено значение этого числа (5).

</details>

***

## * **Metro_stations** 

## Удаление дубликатов

Так как одна станция может находитсья на двух линиях метро, нужно удалить дубликаты:

**Запрос:**

````sql
WITH cte AS (
    SELECT *,
           ROW_NUMBER() OVER (PARTITION BY metro_station ORDER BY metro_station_id) AS rn
    FROM Metro_stations
)
DELETE FROM Metro_stations
WHERE metro_station_id IN (
    SELECT metro_station_id FROM cte WHERE rn > 1
);
````

# Запросы

## Студия или однокомнатная

Сравнение средней арендной платы студий и однокомнатных квартир:

**Запрос:**

````sql
SELECT rooms, COUNT(*) AS offers_amount, AVG(rent_new) AS average_rent
FROM Apartments
GROUP BY rooms
ORDER BY average_rent DESC
````

**Результат:**

| rooms            | offers_amount | average_rent |
|------------------|---------------|--------------|
| Квартира-студия | 69            | 50,721       |
| 1-к. квартира    | 469           | 50,714       |

<details>
<summary>Вывод</summary>

Разница в цене совсем незначительна. Однако можно сделать вывод, что объявлений с однокомнатными квартирами гораздо больше.

</details>

***

## Первый и последний этаж

Сравнение средней арендной платы квартир находящихся на первом или последнем этаже и средней арендной платы квартир на средних этажах:

**Запрос:**

````sql
SELECT 'First and top floor Apartments' AS category, COUNT(*) AS offers_amount, AVG(rent_new) AS average_price
FROM Apartments
WHERE apart_floor = 1 OR apart_floor = total_floor 
UNION
SELECT 'Middle-floor Apartments', COUNT(*), AVG(rent_new)
FROM Apartments
WHERE apart_floor <> 1 AND apart_floor <> total_floor;
````
   
**Результат:**

| category                       | offers_amount | average_price |
|--------------------------------|---------------|---------------|
| First and top floor Apartments | 94            | 48,652        |
| Middle-floor Apartments        | 444           | 51,152        |

<details>
<summary>Вывод</summary>

Средняя плата за квартиры на первом или последнем этаже ниже, чем на остальных.

</details>

***

## Площадь

Сравнение средней арендной платы квартир с площадью ниже среднего и выше среднего:

**Запрос:**

````sql
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
````
**Результат:**

| area_category  | offers_amount | average_rent |
|----------------|---------------|--------------|
| Above Average  | 285           | 52,294       |
| Below Average  | 253           | 48,937       |

<details>
<summary>Вывод</summary>

Площадь даже маленьких квартир имеет большое влияние на формирование арендной платы.

</details>

***

## Время до метро

Сравнение средней арендной платы квартир, от которых пешее время до метро ниже среднего и выше среднего:

**Запрос:**

````sql
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
````

**Результат:**

| time_category  | offers_amount | average_rent |
|----------------|---------------|--------------|
| Above Average  | 165           | 43,454       |
| Below Average  | 354           | 54,760       |

<details>
<summary>Вывод</summary>

Средняя плата за квартиры, находящиеся ближе к метро значительно больше чем за отдаленные от метро.

</details>

***

# Запросы с объединением таблиц 

## Административные округа

Сравнение количества объявлений в разных административных округах Москвы с вычислением процента от общего количества объявлений: 

**Запрос:**

````sql
SELECT adm_area, COUNT(*) AS offers_amount, ROUND(CAST(COUNT(*) AS FLOAT) / SUM(COUNT(*)) OVER () * 100,2) as "percentage"
FROM Apartments AS ap
INNER JOIN Metro_stations AS ms
    ON ap.metro_station = ms.metro_station
GROUP BY adm_area
ORDER BY COUNT(*) DESC;
````

**Результат:**

| adm_area                               | offers_amount | percentage |
|---------------------------------------|---------------|------------|
| Юго-Восточный административный округ   | 68            | 13.1       |
| Юго-Западный административный округ   | 66            | 12.72      |
| Южный административный округ          | 62            | 11.95      |
| Западный административный округ       | 59            | 11.37      |
| Северо-Восточный административный округ| 57            | 10.98      |
| Северный административный округ       | 52            | 10.02      |
| Центральный административный округ    | 52            | 10.02      |
| Восточный административный округ      | 45            | 8.67       |
| Северо-Западный административный округ| 42            | 8.09       |
| Новомосковский административный округ  | 16            | 3.08       |

<details>
<summary>Вывод</summary>

Самыми популярными административными округами являются ЮАО, ЮЗАО, ЮВАО.

</details>

***

Сравнение средней арендной платы квартир в разных административных округах Москвы:

**Запрос:**

````sql
SELECT adm_area, COUNT(*) AS offers_amount, AVG(rent_new) AS average_rent
FROM Apartments AS ap
INNER JOIN Metro_stations AS ms
    ON ap.metro_station = ms.metro_station
GROUP BY adm_area
ORDER BY AVG(rent_new) DESC;
````
**Результат:**

| adm_area                                | offers_amount | average_rent |
|----------------------------------------|---------------|--------------|
| Центральный административный округ       | 52            | 71,567       |
| Северный административный округ          | 52            | 58,282       |
| Западный административный округ          | 59            | 58,066       |
| Северо-Западный административный округ   | 42            | 49,569       |
| Северо-Восточный административный округ  | 57            | 48,426       |
| Южный административный округ             | 62            | 47,822       |
| Новомосковский административный округ    | 16            | 44,936       |
| Юго-Восточный административный округ     | 68            | 44,808       |
| Восточный административный округ         | 45            | 43,977       |
| Юго-Западный административный округ      | 66            | 42,799       |

<details>
<summary>Вывод</summary>

Ожидаемо, за квартиры, находящиеся в ЦАО, нибольшая арендная плата.

</details>

***

## Районы

Сравнение средней арендной платы квартир в разных районах Москвы:

**Запрос:**

````sql
SELECT district, COUNT(*) AS offers_amount, AVG(rent_new) AS average_rent
FROM Apartments AS ap
INNER JOIN Metro_stations AS ms
    ON ap.metro_station = ms.metro_station
GROUP BY district
HAVING COUNT(*) > 10
ORDER BY AVG(rent_new) DESC;
````
**Результат:**

| district                       | offers_amount | average_rent |
|--------------------------------|---------------|--------------|
| Тверской район                  | 11            | 79,090       |
| Хорошёвский район               | 13            | 71,923       |
| Бескудниковский район           | 12            | 52,916       |
| район Хорошёво-Мнёвники         | 11            | 50,362       |
| район Кунцево                   | 16            | 47,187       |
| поселение Внуковское            | 11            | 45,180       |
| район Новогиреево               | 12            | 45,166       |
| район Выхино-Жулебино           | 12            | 39,916       |
| Бабушкинский район              | 12            | 38,666       |
| район Гольяново                 | 11            | 38,454       |
| район Южное Бутово              | 36            | 36,496       |

<details>
<summary>Вывод</summary>

Нибольшая арендная плата за квартиры находящиеся в Тверском и Хорошевском районах.
Район Южное Бутово имеет наименьшую среднюю арендную плату, при высоком количестве предложений. (Учитываются только районы, в которых больше 10 объявлений)

</details>

***

## Линии метро

Сравнение средней арендной платы квартир, располагающихся вблизи станций метро разных линий с помощью объединения и группировки:

**Запрос:**

````sql
SELECT line, COUNT(*) AS offers_amount, AVG(rent_new) AS average_rent
FROM Apartments AS ap
INNER JOIN Metro_stations AS ms
    ON ap.metro_station = ms.metro_station
GROUP BY line
ORDER BY AVG(rent_new) DESC;
````
**Результат:**

| line                               | offers_amount | average_rent |
|------------------------------------|---------------|--------------|
| Филёвская линия                    | 10            | 80,700       |
| Кольцевая линия                    | 1             | 80,000       |
| Сокольническая линия               | 22            | 64,204       |
| Московское центральное кольцо      | 30            | 56,122       |
| Большая кольцевая линия            | 58            | 56,015       |
| Замоскворецкая линия               | 58            | 53,708       |
| Солнцевская линия                  | 24            | 52,995       |
| Серпуховско-Тимирязевская линия    | 46            | 52,445       |
| Люблинско-Дмитровская линия        | 50            | 51,780       |
| Таганско-Краснопресненская линия   | 46            | 51,217       |
| Калужско-Рижская линия             | 43            | 48,016       |
| Калининская линия                  | 16            | 47,875       |
| Арбатско-Покровская линия          | 54            | 45,257       |
| Некрасовская линия                 | 23            | 39,652       |
| Бутовская линия Лёгкого метро       | 38            | 36,628       |

<details>
<summary>Вывод</summary>

Средняя арендная плата различается в зависимости от линии метро: Наибольшая средняя арендная плата наблюдается на Филёвской линии и Кольцевой линии, в то время как на Бутовской линии Лёгкого метро арендная плата значительно ниже.

*данная статистика сильно зависит от входных данных.

</details>

***

# *Хранимая процедура
<details>
<summary> Поиск квартиры </summary>
В дополнение к аналитической работе, я создал хранимую процедуру, которая может помочь находить объявления по вводимым параметрам.

## Создание процедуры

````sql
CREATE PROCEDURE SearchApartments
	@metro_station varchar(50),
	@time_to_metro varchar(50),
	@area varchar(50),
	@rent varchar(50)

AS
BEGIN
	SELECT overview, rent, metro_station, time_to_metro, link
	FROM Apartments
	WHERE 
		(@metro_station IS NULL OR LOWER(metro_station) like '%'+ LOWER(@metro_station) + '%') AND 
		(@time_to_metro IS NULL OR time_to_metro <= CAST(REPLACE(@time_to_metro, ' мин', '') AS FLOAT)) AND 
		(@area IS NULL OR area >= CAST(REPLACE(@area, ' кв', '') AS FLOAT)) AND
		(@rent IS NULL OR rent_new <= CAST(REPLACE(@rent, ' руб', '') AS FLOAT));
END;
````
Пользователь должен ввести название метро, максимальное время до него, минимальную площадь, а также максимальную месячную плату за аренду в таком формате:

````sql
EXEC SearchApartments 'Бабушкинская', '15 мин', '30 кв', '50000 руб';
````
Если какой то из критериев не интересует пользователя, нужно ввести значение NULL:

````sql
EXEC SearchApartments NULL, '15 мин', '30 кв', NULL;
````
## Выполнение процедуры 

**Запрос:**

````sql
EXEC SearchApartments 'Бабушкинская', '15 мин', '30 кв', '50000 руб';
````
**Результат:**

| overview                               | rent                | metro_station | time_to_metro | link                                                                                     |
|----------------------------------------|---------------------|---------------|---------------|------------------------------------------------------------------------------------------|
| 1-к. квартира, 34,9 м², 9/12 эт.       | 45 000 ₽ в месяц   | Бабушкинская  | 5             | https://www.avito.ru/moskva/kvartiry/1-k._kvartira_349m_912et._3319449837    |
| 1-к. квартира, 32 м², 4/5 эт.          | 34 000 ₽ в месяц   | Бабушкинская  | 13            | https://www.avito.ru/moskva/kvartiry/1-k._kvartira_32m_45et._2704641934     |
| 1-к. квартира, 39,4 м², 2/17 эт.       | 40 000 ₽ в месяц   | Бабушкинская  | 13            | https://www.avito.ru/moskva/kvartiry/1-k._kvartira_394m_217et._3396550547    |

***
**Запрос:**

````sql
EXEC SearchApartments NULL, '10 мин', '20 кв', '30000 руб';
````
**Результат:**

| overview                               | rent                | metro_station            | time_to_metro | link                                                                                     |
|----------------------------------------|---------------------|--------------------------|---------------|------------------------------------------------------------------------------------------|
| 1-к. квартира, 26 м², 2/5 эт.          | 30 000 ₽ в месяц   | Кузьминки                | 8             | https://www.avito.ru/moskva/kvartiry/1-k._kvartira_26m_25et._3419150713    |
| 1-к. квартира, 35 м², 5/9 эт.          | 30 000 ₽ в месяц   | Орехово                  | 8             | https://www.avito.ru/moskva/kvartiry/1-k._kvartira_35m_59et._3049980415    |
| 1-к. квартира, 40 м², 2/22 эт.         | 28 000 ₽ в месяц   | Улица Старокачаловская   | 8             | https://www.avito.ru/moskva/kvartiry/1-k._kvartira_40m_222et._2875150414    |
| 1-к. квартира, 37 м², 7/12 эт.         | 30 000 ₽ в месяц   | Перово                   | 5             | https://www.avito.ru/moskva/kvartiry/1-k._kvartira_37m_712et._3170968304    |
| 1-к. квартира, 37 м², 7/9 эт.          | 30 000 ₽ в месяц   | Отрадное                 | 8             | https://www.avito.ru/moskva/kvartiry/1-k._kvartira_37m_79et._3145945902    |
| Квартира-студия, 23 м², 14/17 эт.      | 30 000 ₽ в месяц   | Некрасовка               | 8             | https://www.avito.ru/moskva/kvartiry/kvartira-studiya_23m_1417et._3240655447 |
| 1-к. квартира, 32 м², 8/9 эт.          | 30 000 ₽ в месяц   | Беломорская              | 8             | https://www.avito.ru/moskva/kvartiry/1-k._kvartira_32m_89et._3240143297    |
| 1-к. квартира, 38 м², 2/12 эт.         | 30 000 ₽ в месяц   | Бунинская аллея          | 8             | https://www.avito.ru/moskva/kvartiry/1-k._kvartira_38m_212et._1649205943    |


</details>

***

# Заключение

В рамках данного проекта был проведен анализ данных объявлений о сдаче квартир в аренду с целью подтверждения или опровержения предварительных гипотез и ответа на ключевые вопросы, связанные с рынком аренды жилья. 

В ходе выполнения работы был проведен процесс сбора и обработки данных. Исходные данные были подвергнуты преобразованию и очистке, чтобы обеспечить удобство в последующем анализе, проведенном с помощью запросов SQL.

# Спасибо за внимание!
