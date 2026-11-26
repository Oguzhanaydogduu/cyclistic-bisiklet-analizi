/* =====================================================================
   03 · VERİ TEMİZLİĞİ
   ---------------------------------------------------------------------
   Amaç   : Hatalı ve analiz dışı sürüşleri ayıklamak, her kuralın kaç
            satır sildiğini kayıt altına almak.
   Girdi  : dbo.divvy_2025_prep
   Çıktı  : dbo.divvy_2025_clean (analiz tablosu)
            dbo.cleaning_log      (temizlik kaydı)
   Bilinçli karar:
     İstasyon adı boş sürüşler SİLİNMEDİ. Bunların çoğu istasyon dışına
     bırakılabilen elektrikli bisikletler; silinseydi elektrikli bisiklet
     kullanımı ve onu yoğun kullanan segment olduğundan düşük görünürdü.
     Bu satırlar yalnızca istasyon analizinin dışında tutuluyor.
   ===================================================================== */

-- 0) Ön bakış: test / bakım istasyonları (hiçbir şey silmez)
--    COLLATE şart: Türkçe harmanlamada 'i' ile 'I' eşleşmez, LIKE satır kaçırır
SELECT istasyon, COUNT(*) AS adet
FROM (SELECT start_station_name AS istasyon FROM dbo.divvy_2025_prep
      UNION ALL
      SELECT end_station_name FROM dbo.divvy_2025_prep) x
WHERE istasyon COLLATE Latin1_General_CI_AS LIKE '%test%'
   OR istasyon COLLATE Latin1_General_CI_AS LIKE '%repair%'
GROUP BY istasyon
ORDER BY adet DESC;


-- 1) Temizlik (tek seferde, GO olmadan çalıştırın)
DROP TABLE IF EXISTS dbo.divvy_2025_clean;
DROP TABLE IF EXISTS dbo.cleaning_log;

SELECT * INTO dbo.divvy_2025_clean FROM dbo.divvy_2025_prep;

CREATE TABLE dbo.cleaning_log (adim int, kural nvarchar(200), silinen int);
DECLARE @n int;

-- Kural 1: eksik zorunlu alanlar
DELETE FROM dbo.divvy_2025_clean
WHERE ride_id IS NULL OR started_at IS NULL OR ended_at IS NULL;
SET @n = @@ROWCOUNT;
INSERT INTO dbo.cleaning_log VALUES (1, N'ride_id / started_at / ended_at boş', @n);

-- Kural 2: geçersiz kullanıcı tipi
DELETE FROM dbo.divvy_2025_clean
WHERE member_casual IS NULL OR member_casual NOT IN ('member', 'casual');
SET @n = @@ROWCOUNT;
INSERT INTO dbo.cleaning_log VALUES (2, N'member_casual geçersiz', @n);

-- Kural 3: tekrar eden ride_id (ilk kayıt kalır)
WITH d AS (
    SELECT ROW_NUMBER() OVER (PARTITION BY ride_id ORDER BY started_at) AS rn
    FROM dbo.divvy_2025_clean
)
DELETE FROM d WHERE rn > 1;
SET @n = @@ROWCOUNT;
INSERT INTO dbo.cleaning_log VALUES (3, N'Tekrar eden ride_id', @n);

-- Kural 4: bitişi başlangıçtan önce veya aynı anda olan sürüşler
DELETE FROM dbo.divvy_2025_clean WHERE ended_at <= started_at;
SET @n = @@ROWCOUNT;
INSERT INTO dbo.cleaning_log VALUES (4, N'Süre sıfır veya negatif', @n);

-- Kural 5: 1 dakikadan kısa sürüşler (yanlış kilit açma / anında iade)
DELETE FROM dbo.divvy_2025_clean WHERE ride_length_min < 1;
SET @n = @@ROWCOUNT;
INSERT INTO dbo.cleaning_log VALUES (5, N'1 dakikadan kısa', @n);

-- Kural 6: 24 saatten uzun sürüşler (iade edilmemiş / kayıp bisiklet)
DELETE FROM dbo.divvy_2025_clean WHERE ride_length_min > 1440;
SET @n = @@ROWCOUNT;
INSERT INTO dbo.cleaning_log VALUES (6, N'24 saatten uzun', @n);

-- Kural 7: test / bakım istasyonları
DELETE FROM dbo.divvy_2025_clean
WHERE start_station_name COLLATE Latin1_General_CI_AS LIKE '%test%'
   OR start_station_name COLLATE Latin1_General_CI_AS LIKE '%repair%'
   OR end_station_name   COLLATE Latin1_General_CI_AS LIKE '%test%'
   OR end_station_name   COLLATE Latin1_General_CI_AS LIKE '%repair%';
SET @n = @@ROWCOUNT;
INSERT INTO dbo.cleaning_log VALUES (7, N'Test / bakım istasyonu', @n);

-- Temizlik raporu
DECLARE @baslangic int = (SELECT COUNT(*) FROM dbo.divvy_2025_prep);

SELECT adim, kural, silinen,
       @baslangic - SUM(silinen) OVER (ORDER BY adim ROWS UNBOUNDED PRECEDING) AS kalan,
       CAST(100.0 * silinen / @baslangic AS decimal(5,2))                       AS silinen_yuzde
FROM dbo.cleaning_log
ORDER BY adim;
/* Sonuç:
   adim  kural                                silinen    kalan      %
   1     ride_id / started_at / ended_at boş        0    5.552.994  0,00
   2     member_casual geçersiz                     0    5.552.994  0,00
   3     Tekrar eden ride_id                        0    5.552.994  0,00
   4     Süre sıfır veya negatif                   29    5.552.965  0,00
   5     1 dakikadan kısa                     146.894    5.406.071  2,65
   6     24 saatten uzun                        5.585    5.400.486  0,10
   7     Test / bakım istasyonu                     0    5.400.486  0,00
*/


-- 2) Yanlılık kontrolü: silinen kısa sürüşler bir segmentte mi yoğunlaşıyor?
SELECT member_casual, COUNT(*) AS silinen_kisa_surus
FROM dbo.divvy_2025_prep
WHERE ride_length_min > 0 AND ride_length_min < 1
GROUP BY member_casual;
