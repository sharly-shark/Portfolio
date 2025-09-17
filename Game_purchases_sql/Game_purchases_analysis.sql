/* Проект «Секреты Тёмнолесья»
 * Цель проекта: изучить влияние характеристик игроков и их игровых персонажей 
 * на покупку внутриигровой валюты «райские лепестки», а также оценить 
 * активность игроков при совершении внутриигровых покупок
 * 
 * Автор: Елагина Ксения Станниславовна
*/

-- Часть 1. Исследовательский анализ данных
-- Задача 1. Исследование доли платящих игроков

--title: 1.1. Доля платящих пользователей по всем данным:
SELECT count (id) AS total_players,
(SELECT sum (payer) FROM fantasy.users WHERE payer=1) AS total_donaters,
round (avg (payer), 3) AS donaters_part_over_total_players
FROM fantasy.users;


--title: 1.2. Доля платящих пользователей в разрезе расы персонажа:
SELECT race,
sum (payer) AS total_donaters,
count (id) AS total_players,
round (avg (payer), 3) AS donaters_part_over_total_players_by_race
FROM fantasy.users
INNER JOIN fantasy.race USING (race_id)
GROUP BY race
ORDER BY total_donaters DESC, total_players DESC;

-- Задача 2. Исследование внутриигровых покупок

--title: 2.1. Статистические показатели по полю amount + сравнение с показателями без нулевых покупок:
SELECT 'statistic_with_zero_amount' AS statistic,
count (*) AS total_purchases,
sum (amount) AS sum_purchases,
min (amount) AS min_purchases,
max (amount) AS max_purchases,
round (avg (amount)::numeric, 2) AS avg_purchases,
percentile_disc (0.5) WITHIN GROUP (ORDER BY amount) AS purchases_mediana,
stddev (amount) AS stddev_purchases
FROM fantasy.events
UNION ALL
SELECT 'statistic_without_zero_amount' AS statistic,
count (*) AS total_purchases,
sum (amount) AS sum_purchases,
min (amount) AS min_purchuases,
max (amount) AS max_purchases,
round (avg (amount)::numeric, 2) AS avg_purchases,
percentile_disc (0.5) WITHIN GROUP (ORDER BY amount) AS purchases_mediana,
round (stddev (amount)::NUMERIC, 3) AS stddev_purchases
FROM fantasy.events
WHERE amount>0
ORDER BY statistic;


--title: 2.2: Аномальные нулевые покупки:
SELECT count (amount) AS total_zero_purchases,
count(*)/(SELECT count(*) FROM fantasy.events)::float4 AS zero_part_over_total
FROM fantasy.events 
WHERE amount = 0; 

--title: Предметы за 0 р.л.:
SELECT DISTINCT id,
game_items,
count (amount) AS total_zero_purchases,
count (DISTINCT amount) AS total_count_of_game_item
FROM fantasy.items
JOIN fantasy.events USING (item_code)
WHERE amount = 0
GROUP BY id, game_items
ORDER BY total_zero_purchases DESC;

--title: 2.3: Сравнительный анализ активности платящих и неплатящих игроков:
WITH purchases_without_zero_amount AS 
(SELECT id,
count (id) AS total_purchases,
sum (amount) AS sum_purchases
FROM fantasy.events
WHERE amount>0
GROUP BY id)
SELECT CASE
        WHEN payer = 0 THEN 'not_donaters'
        WHEN payer = 1 THEN 'donaters'
END AS players_group,
count (id) AS total_players,
avg (total_purchases) AS avg_purchases,
avg (sum_purchases) AS avg_purchases_amount
FROM purchases_without_zero_amount
JOIN fantasy.users USING (id)
GROUP BY payer
ORDER BY players_group DESC;

--title: Сравнение платящих и неплатящих в разрезе рас:
WITH purchases_without_zero_amount AS 
(SELECT id,
count (id) AS total_purchases,
sum (amount) AS sum_purchases
FROM fantasy.events
WHERE amount>0
GROUP BY id)
SELECT CASE
        WHEN payer = 0 THEN 'not_donaters'
        WHEN payer = 1 THEN 'donaters'
END AS players_group,
race,
count (id),
round (avg (total_purchases)::numeric, 2) AS avg_purchases,
round (avg (sum_purchases)::NUMERIC, 2) AS avg_purchases_amount
FROM purchases_without_zero_amount
JOIN fantasy.users USING (id)
JOIN fantasy.race USING (race_id)
GROUP BY payer, race
ORDER BY race, players_group;

--title: 2.4: Популярные эпические предметы:
SELECT game_items,
count (id) AS total_purchases,
count(id)/(SELECT count(id) FROM fantasy.events)::float4 AS each_purchases_part_over_total,
count (DISTINCT id)/(SELECT count (id) FROM fantasy.users)::float4 AS part_of_payers_over_total_players,
count (DISTINCT id)/(SELECT count (DISTINCT id) FROM fantasy.events)::float4 AS part_of_payers_by_item_over_total_payers
FROM fantasy.events
JOIN fantasy.items USING (item_code)
WHERE amount>0
GROUP BY game_items
ORDER BY total_purchases DESC;

--title: Количество эпических предметов, которые ни разу не купили:
SELECT count (i.item_code) AS total_items_never_bought
FROM fantasy.items i 
LEFT JOIN fantasy.events e ON (i.item_code=e.item_code)
WHERE e.item_code IS NULL AND amount>0;

--title: Количество эпических предметов, которые купили 1 раз:
WITH total_purchases_by_item AS (SELECT game_items,
count (id) AS total_purchases
FROM fantasy.events
JOIN fantasy.items USING (item_code)
WHERE amount>0
GROUP BY game_items)
SELECT count (total_purchases) AS total_items_with_one_purchases
FROM total_purchases_by_item
WHERE total_purchases = 1;

--title: Количество эпических предметов
-- Часть 2. Решение ad hoc-задач
--title: Задача 1. Зависимость активности игроков от расы персонажа:
WITH total_players_by_race AS (SELECT race,
count (id) AS total_players
FROM fantasy.users 
LEFT JOIN fantasy.race USING (race_id)
GROUP BY race),
--
     total_payers_by_race AS (SELECT race,
count (DISTINCT id) AS total_payers,
avg (amount) AS avg_amount_over_one_player
FROM fantasy.events
LEFT JOIN fantasy.users USING (id)
LEFT JOIN fantasy.race USING (race_id)
WHERE amount>0
GROUP BY race),
--
     total_donaters_with_purchases_by_race AS (SELECT race,
count (DISTINCT id) AS total_donaters_with_purchases
FROM fantasy.users 
JOIN fantasy.events USING (id)
LEFT JOIN fantasy.race USING (race_id)
WHERE payer = 1
GROUP BY race),
--
      total_purchases_and_sum_of_purchases_by_race_and_id AS (SELECT race,
id,
count (id) AS total_purchases,
sum (amount) AS sum_amount
FROM fantasy.events
LEFT JOIN fantasy.users USING (id)
LEFT JOIN fantasy.race USING (race_id)
WHERE amount>0
GROUP BY race,id),
--
      avg_purchases_and_avg_amount_by_race as (SELECT race,
avg (total_purchases) AS avg_purchases_over_one_player,
avg (sum_amount) AS avg_sum_amount_over_one_player
FROM total_purchases_and_sum_of_purchases_by_race_and_id
GROUP BY race)
--
SELECT race,
total_players,
total_payers,
total_payers/total_players::float4 AS part_of_payers_over_players,
total_donaters_with_purchases/total_payers::float4 AS part_of_donaters_over_payers,
avg_purchases_over_one_player,
avg_amount_over_one_player,
avg_sum_amount_over_one_player
FROM total_players_by_race
JOIN total_payers_by_race USING (race)
JOIN total_donaters_with_purchases_by_race USING (race)
JOIN avg_purchases_and_avg_amount_by_race USING (race)
ORDER BY total_players DESC, total_payers DESC;


--title:Задача 2. Частота покупок*
WITH days_between_purchases_over_player AS (SELECT id,
transaction_id,
date::date - (LAG (date::date) OVER (PARTITION BY id ORDER BY date::date)) AS days_between_purchases
FROM fantasy.events
WHERE amount>0),
--
total_purchases_and_avg_day_interval_over_player AS (SELECT id,
payer,
count (transaction_id) AS total_purchases,
avg (days_between_purchases) AS avg_day_interval
FROM days_between_purchases_over_player
JOIN fantasy.users USING (id)
GROUP BY id, payer
HAVING count (transaction_id) >=25
ORDER BY avg_day_interval),
--
three_groups_over_purchases_frequency_by_number AS (SELECT *, 
NTILE(3) OVER (ORDER BY avg_day_interval) AS purchases_frequency_by_number
FROM total_purchases_and_avg_day_interval_over_player),
--
name_of_purchases_frequency AS (SELECT id,
payer,
total_purchases,
avg_day_interval, 
CASE WHEN purchases_frequency_by_number = 1
THEN 'высокая частота'
WHEN purchases_frequency_by_number = 2
THEN 'умеренная частота'
WHEN purchases_frequency_by_number = 3
THEN 'низкая частота'
END AS purchases_frequency 
FROM three_groups_over_purchases_frequency_by_number),
--
all_calculations AS (SELECT purchases_frequency,
count (id) AS total_payers,
count (id) FILTER (WHERE payer = 1) AS total_donaters_with_purchases,
avg (total_purchases) AS avg_purchases_over_one_player,
avg (avg_day_interval) AS avg_day_interval_for_each_frequency
FROM name_of_purchases_frequency
GROUP BY purchases_frequency)
--
SELECT purchases_frequency,
avg_day_interval_for_each_frequency,
total_payers,
total_donaters_with_purchases,
total_donaters_with_purchases/total_payers::float4 AS part_of_donaters_over_payers,
avg_purchases_over_one_player
FROM all_calculations
ORDER BY total_donaters_with_purchases DESC; 
