/* =====================================================================
   02 · HESAPLANAN SÜTUNLAR
   ---------------------------------------------------------------------
   Amaç   : Her sürüşe analizde kullanılacak türetilmiş sütunları eklemek.
   Girdi  : dbo.divvy_2025
   Çıktı  : dbo.divvy_2025_prep
   Sütunlar:
     ride_length_min : sürüş süresi (dakika)
     day_of_week     : 1 = Pazar … 7 = Cumartesi (vaka çalışmasındaki WEEKDAY ile aynı)
     day_name        : Türkçe gün adı
     start_hour      : başlangıç saati (0–23)
     ride_month      : ay (1–12)
     season          : mevsim
   Not    : 5 milyonu aşkın satırda UPDATE yerine SELECT … INTO çok daha hızlı.
   ===================================================================== */

SET DATEFIRST 7;   -- Türkçe oturumlarda varsayılan Pazartesi olduğu için şart

DROP TABLE IF EXISTS dbo.divvy_2025_prep;

SELECT
    d.*,
    CAST(DATEDIFF(SECOND, d.started_at, d.ended_at) / 60.0 AS decimal(10,2)) AS ride_length_min,
    DATEPART(WEEKDAY, d.started_at) AS day_of_week,
    CASE DATEPART(WEEKDAY, d.started_at)
        WHEN 1 THEN N'Pazar'     WHEN 2 THEN N'Pazartesi' WHEN 3 THEN N'Salı'
        WHEN 4 THEN N'Çarşamba'  WHEN 5 THEN N'Perşembe'  WHEN 6 THEN N'Cuma'
        WHEN 7 THEN N'Cumartesi' END                AS day_name,
    DATEPART(HOUR, d.started_at)                    AS start_hour,
    MONTH(d.started_at)                             AS ride_month,
    CASE WHEN MONTH(d.started_at) IN (12, 1, 2) THEN N'Kış'
         WHEN MONTH(d.started_at) IN (3, 4, 5)  THEN N'İlkbahar'
         WHEN MONTH(d.started_at) IN (6, 7, 8)  THEN N'Yaz'
         ELSE N'Sonbahar' END                       AS season
INTO dbo.divvy_2025_prep
FROM dbo.divvy_2025 d;


-- Kontrol: negatif ve aşırı uzun süreler burada görünür, 03'te temizlenir
SELECT MIN(ride_length_min) AS en_kisa,
       MAX(ride_length_min) AS en_uzun,
       AVG(ride_length_min) AS ortalama
FROM dbo.divvy_2025_prep;
