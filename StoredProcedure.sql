-- Создание процедуры поиска объявлений
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

-- Введите критерии подбора квартиры в таком формате: 'сходненская', '10 мин', '25 кв', '70000 руб'
EXEC SearchApartments 'бабушкинская', '20 мин', '20 кв', '50000 руб';
EXEC SearchApartments NULL, NULL, '50 кв', NULL;

