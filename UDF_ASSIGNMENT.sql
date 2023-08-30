--1. Scalar Functions
--Convert all film titles in the film table to uppercase.

--REPLACE COLUMN
UPDATE public.film
SET title = UPPER(title)
                        	

--Calculate the length in hours (rounded to 2 decimal places) for each film in the film table.

SELECT 
	se_film.film_id AS film_id,
	ROUND(se_film.length/60.0,2) AS length_in_hours
FROM public.film AS se_film

--Extract the year from the last_update column in the actor table.

SELECT 
	se_actor.actor_id AS actor_id,
	EXTRACT (YEAR FROM se_actor.last_update) AS last_update_year
FROM public.actor AS se_actor
	

--2. Aggregate Functions

--Count the total number of films in the film table.
CREATE VIEW total_number_of_films AS 
(

	SELECT
		COUNT(se_film.film_id) AS total_films
	FROM public.film AS se_film
);
SELECT
	*
FROM total_number_of_films

--Calculate the average rental rate of films in the film table.

CREATE VIEW average_rental_rate AS 
(

	SELECT
		ROUND(AVG(se_film.rental_rate),2) AS average_rental_rate
	FROM public.film AS se_film
);
SELECT
	*
FROM average_rental_rate


--Determine the highest and lowest film lengths.

CREATE VIEW MIN_MAX_FILM_LENGTH AS 
(

	SELECT
		MAX(se_film.length) AS highest_film_length,
		MIN(se_film.length) AS lowest_film_length
	FROM public.film AS se_film
);
SELECT
	*
FROM MIN_MAX_FILM_LENGTH

--Find the total number of films in each film category.

CREATE VIEW TOTAL_FILMS_PER_CATEGORY AS (
	
	SELECT
		se_category.name AS category,
		COUNT(se_film.film_id) AS total_films
	
	FROM public.category AS se_category	
	LEFT OUTER JOIN public.film_category AS se_film_category
	ON se_film_category.category_id = se_category.category_id 	
	LEFT OUTER JOIN public.film AS se_film
	ON se_film.film_id = se_film_category.film_id
	GROUP BY
		se_category.name
);

SELECT
	*
FROM TOTAL_FILMS_PER_CATEGORY


--3. Window Functions

--Rank films in the film table by length using the RANK() function.

CREATE VIEW FILM_LENGTH_RANKING AS
(
	SELECT 
		se_film.film_id AS film_id,
		se_film.length AS film_length,
		RANK () OVER (ORDER BY se_film.length DESC ) AS length_rank
	FROM public.film AS se_film
	ORDER BY 
		RANK () OVER (ORDER BY se_film.length DESC), 
		se_film.film_id
);
SELECT
	*
FROM FILM_LENGTH_RANKING


--Calculate the cumulative sum of film lengths in the film table using the SUM() window function.

CREATE VIEW CUMMULATIVE_LENGTH AS
(
	SELECT 
		se_film.film_id AS film_id,
		se_film.length AS film_length,
		SUM (se_film.length) OVER (ORDER BY se_film.film_id ) AS running_length
	FROM public.film AS se_film
);
SELECT
	*
FROM CUMMULATIVE_LENGTH


--For each film in the film table, retrieve the title of the next film in terms of alphabetical order using the LEAD() function.

CREATE VIEW FILM_LEAD AS
(
	SELECT 
		se_film.film_id AS film_id,
		se_film.title AS film_title,
		LEAD (se_film.title) OVER (ORDER BY se_film.title ) AS leading_title
	FROM public.film AS se_film
);
SELECT
	*
FROM FILM_LEAD

--4. Conditional Functions

--Classify films in the film table based on their lengths:
--Short (< 60 minutes)
--Medium (60 - 120 minutes)
--Long (> 120 minutes)

CREATE VIEW LENGTH_CLASSIFICATION AS
(
	SELECT 
		se_film.film_id AS film_id,
		se_film.title AS film_title,
		se_film.length AS film_length,
		CASE 
			WHEN
			se_film.length <60 THEN 'short'
			WHEN se_film.length <120 THEN 'medium'
			ELSE 'long' 
		END AS length_classification
	FROM public.film AS se_film
);
SELECT
	*
FROM LENGTH_CLASSIFICATION


--For each payment in the payment table, use the COALESCE function to replace null values in the amount column with the average payment amount.

--VIEW
CREATE VIEW COALESCE_AVERAGE_PAYMENT AS(
	SELECT 
		se_payment.payment_id,
		COALESCE(se_payment.amount, (SELECT AVG(amount) FROM public.payment))
	FROM public.payment AS se_payment
);

SELECT *
	FROM COALESCE_AVERAGE_PAYMENT

--PERMENANT 
UPDATE public.payment
SET amount = COALESCE(amount,(SELECT AVG(amount) FROM public.payment))


--5. User-Defined Functions (UDFs)

--Create a UDF named film_category that accepts a film title as input and returns the category of the film.
CREATE OR REPLACE FUNCTION public.film_category (INPUT_FILM_TITLE TEXT )
RETURNS TEXT AS
$$
DECLARE
	category_name TEXT;
BEGIN

	SELECT
		COALESCE (se_category.name, 'no category')
	INTO category_name
	FROM public.film AS se_film
	LEFT OUTER JOIN public.film_category AS se_film_category
		ON se_film.film_id = se_film_category.film_id
	LEFT OUTER JOIN public.category AS se_category
		ON se_film_category.category_id = se_category.category_id 
	WHERE lower(se_film.title) = INPUT_FILM_TITLE;
	RETURN category_name;
END;
$$ LANGUAGE plpgsql

SELECT
	*
FROM film_category ('african egg')


--Develop a UDF named total_rentals that takes a film title as an argument and returns the total number of times the film has been rented.

CREATE OR REPLACE FUNCTION public.total_rentals(INPUT_FILM_TITLE TEXT)
RETURNS INTEGER AS
$$
DECLARE
	number_rented INTEGER;
BEGIN
	SELECT
		COALESCE(COUNT(se_rental.rental_id),0)
	INTO number_rented
	FROM public.film AS se_film
	LEFT OUTER JOIN public.inventory AS se_inventory
		ON se_film.film_id = se_inventory.film_id
	LEFT OUTER JOIN public.rental AS se_rental
		ON se_inventory.inventory_id = se_inventory.inventory_id  
	WHERE lower(se_film.title) = INPUT_FILM_TITLE;
	RETURN number_rented;
END;
$$ LANGUAGE plpgsql

SELECT
	*
FROM total_rentals ('african egg')


--Design a UDF named customer_stats which takes a customer ID as input and returns a JSON containing the customer's name, total rentals, and total amount spent.

CREATE OR REPLACE FUNCTION public.customer_stats (input_customer_id INT)
RETURNS JSONB AS
$$
DECLARE
	return_json JSONB;
BEGIN
	SELECT 
		JSONB_AGG( row_to_json (customer_rentals.*))
	INTO return_json
	FROM 
		(SELECT 
			se_customer.first_name,
			COUNT(COALESCE(se_rental.rental_id,0)) AS total_rentals,
			SUM(COALESCE(se_payment.amount,0)) AS total_amount_spent
		FROM public.customer AS se_customer
		LEFT OUTER JOIN public.rental AS se_rental
			ON se_customer.customer_id = se_rental.customer_id
		LEFT OUTER JOIN public.payment AS se_payment
			ON se_customer.customer_id = se_payment.customer_id
		WHERE se_customer.customer_id = input_customer_id
		GROUP BY
			se_customer.first_name
		) AS customer_rentals;
	RETURN return_json;	
END;
$$ LANGUAGE plpgsql;

SELECT * FROM public.customer_stats(input_customer_id := 73);















