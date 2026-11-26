/* =====================================================================
   04 · MEMBER / CASUAL ÖZET TABLOLARI
   ---------------------------------------------------------------------
   Amaç   : Power BI ve rapor için member ile casual'ı karşılaştıran
            özet tabloları üretmek.
   Girdi  : dbo.divvy_2025_clean
   Çıktı  : dbo.ozet_genel, ozet_gun, ozet_saat, ozet_ay, ozet_bisiklet,
            ozet_sure_araligi, ozet_istasyon, ozet_gidis_donus
   Not    : segment_ici_pay = bir segmentin sürüşlerinin yüzde kaçının o
            gruba düştüğü. Member'lar sayıca fazla olduğundan ham sayılar
            yerine bu oran karşılaştırılır.
   ===================================================================== */

-- 4.1 Genel: sayı, pay, ortalama ve medyan süre
DROP TABLE IF EXISTS dbo.ozet_genel;
WITH m AS (
    SELECT DISTINCT member_casual,
           PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY ride_length_min)
               OVER (PARTITION BY member_casual) AS medyan_dk
    FROM dbo.divvy_2025_clean
)
SELECT c.member_casual,
       COUNT(*)                                                       AS surus_sayisi,
       CAST(100.0 * COUNT(*) / SUM(COUNT(*)) OVER () AS decimal(5,2)) AS pay_yuzde,
       CAST(AVG(c.ride_length_min) AS decimal(10,2))                  AS ortalama_dk,
       CAST(MAX(m.medyan_dk) AS decimal(10,2))                        AS medyan_dk
INTO dbo.ozet_genel
FROM dbo.divvy_2025_clean c
JOIN m ON m.member_casual = c.member_casual
GROUP BY c.member_casual;

-- 4.2 Haftanın günü
DROP TABLE IF EXISTS dbo.ozet_gun;
SELECT member_casual, day_of_week, day_name,
       COUNT(*)                                    AS surus_sayisi,
       CAST(AVG(ride_length_min) AS decimal(10,2)) AS ortalama_dk,
       CAST(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (PARTITION BY member_casual) AS decimal(5,2)) AS segment_ici_pay
INTO dbo.ozet_gun
FROM dbo.divvy_2025_clean
GROUP BY member_casual, day_of_week, day_name;

-- 4.3 Günün saati
DROP TABLE IF EXISTS dbo.ozet_saat;
SELECT member_casual, start_hour,
       COUNT(*)                                    AS surus_sayisi,
       CAST(AVG(ride_length_min) AS decimal(10,2)) AS ortalama_dk,
       CAST(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (PARTITION BY member_casual) AS decimal(5,2)) AS segment_ici_pay
INTO dbo.ozet_saat
FROM dbo.divvy_2025_clean
GROUP BY member_casual, start_hour;

-- 4.4 Ay ve mevsim
DROP TABLE IF EXISTS dbo.ozet_ay;
SELECT member_casual, ride_month, season,
       COUNT(*)                                    AS surus_sayisi,
       CAST(AVG(ride_length_min) AS decimal(10,2)) AS ortalama_dk,
       CAST(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (PARTITION BY member_casual) AS decimal(5,2)) AS segment_ici_pay
INTO dbo.ozet_ay
FROM dbo.divvy_2025_clean
GROUP BY member_casual, ride_month, season;

-- 4.5 Bisiklet tipi
DROP TABLE IF EXISTS dbo.ozet_bisiklet;
SELECT member_casual, rideable_type,
       COUNT(*)                                    AS surus_sayisi,
       CAST(AVG(ride_length_min) AS decimal(10,2)) AS ortalama_dk,
       CAST(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (PARTITION BY member_casual) AS decimal(5,2)) AS segment_ici_pay
INTO dbo.ozet_bisiklet
FROM dbo.divvy_2025_clean
GROUP BY member_casual, rideable_type;

-- 4.6 Süre dağılımı (histogram için)
DROP TABLE IF EXISTS dbo.ozet_sure_araligi;
SELECT member_casual, sure_araligi, sira,
       COUNT(*) AS surus_sayisi,
       CAST(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (PARTITION BY member_casual) AS decimal(5,2)) AS segment_ici_pay
INTO dbo.ozet_sure_araligi
FROM (
    SELECT member_casual,
           CASE WHEN ride_length_min < 5  THEN N'1-5 dk'
                WHEN ride_length_min < 10 THEN N'5-10 dk'
                WHEN ride_length_min < 20 THEN N'10-20 dk'
                WHEN ride_length_min < 30 THEN N'20-30 dk'
                WHEN ride_length_min < 60 THEN N'30-60 dk'
                ELSE N'60+ dk' END AS sure_araligi,
           CASE WHEN ride_length_min < 5  THEN 1 WHEN ride_length_min < 10 THEN 2
                WHEN ride_length_min < 20 THEN 3 WHEN ride_length_min < 30 THEN 4
                WHEN ride_length_min < 60 THEN 5 ELSE 6 END AS sira
    FROM dbo.divvy_2025_clean
) x
GROUP BY member_casual, sure_araligi, sira;

-- 4.7 En popüler 10 başlangıç istasyonu (segment başına)
DROP TABLE IF EXISTS dbo.ozet_istasyon;
WITH s AS (
    SELECT member_casual, start_station_name,
           COUNT(*) AS surus_sayisi,
           ROW_NUMBER() OVER (PARTITION BY member_casual ORDER BY COUNT(*) DESC) AS sira
    FROM dbo.divvy_2025_clean
    WHERE start_station_name IS NOT NULL
    GROUP BY member_casual, start_station_name
)
SELECT * INTO dbo.ozet_istasyon FROM s WHERE sira <= 10;

-- 4.8 Gidiş-dönüş sürüşleri (başladığı istasyona geri bırakılan)
DROP TABLE IF EXISTS dbo.ozet_gidis_donus;
SELECT member_casual,
       COUNT(*) AS istasyonlu_surus,
       SUM(CASE WHEN start_station_name = end_station_name THEN 1 ELSE 0 END) AS gidis_donus,
       CAST(100.0 * SUM(CASE WHEN start_station_name = end_station_name THEN 1 ELSE 0 END)
            / COUNT(*) AS decimal(5,2)) AS gidis_donus_yuzde
INTO dbo.ozet_gidis_donus
FROM dbo.divvy_2025_clean
WHERE start_station_name IS NOT NULL AND end_station_name IS NOT NULL
GROUP BY member_casual;


-- Sonuçlar
SELECT * FROM dbo.ozet_genel;
SELECT * FROM dbo.ozet_gun          ORDER BY member_casual, day_of_week;
SELECT * FROM dbo.ozet_saat         ORDER BY member_casual, start_hour;
SELECT * FROM dbo.ozet_ay           ORDER BY member_casual, ride_month;
SELECT * FROM dbo.ozet_bisiklet     ORDER BY member_casual, surus_sayisi DESC;
SELECT * FROM dbo.ozet_sure_araligi ORDER BY member_casual, sira;
SELECT * FROM dbo.ozet_istasyon     ORDER BY member_casual, sira;
SELECT * FROM dbo.ozet_gidis_donus;
