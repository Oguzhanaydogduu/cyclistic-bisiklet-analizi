/* =====================================================================
   01 · VERİ BİRLEŞTİRME
   ---------------------------------------------------------------------
   Amaç   : SSMS ile ayrı tablolara aktarılan 12 aylık Divvy CSV'sini
            (dbo.[2025MM-divvy-tripdata-<ay>]) tek bir tabloda birleştirmek.
   Çıktı  : dbo.divvy_2025
   Not    : İçe aktarma sihirbazı her ayda sütun tiplerini farklı tahmin
            edebildiği için düz UNION ALL yerine sabit tipli bir hedef tablo
            oluşturulup her ay TRY_CONVERT ile ekleniyor. Dönüştürülemeyen
            değerler hata yerine NULL olur ve doğrulama adımında yakalanır.
   ===================================================================== */

-- 0) Ön kontrol: 12 tablo bulunmalı
SELECT name
FROM sys.tables
WHERE name LIKE N'2025[01][0-9]-divvy-tripdata%';


-- 1) Sabit tipli hedef tablo
DROP TABLE IF EXISTS dbo.divvy_2025;

CREATE TABLE dbo.divvy_2025 (
    ride_id            varchar(20),
    rideable_type      varchar(20),
    started_at         datetime2(3),
    ended_at           datetime2(3),
    start_station_name nvarchar(150),
    start_station_id   nvarchar(50),
    end_station_name   nvarchar(150),
    end_station_id     nvarchar(50),
    start_lat          float,
    start_lng          float,
    end_lat            float,
    end_lng            float,
    member_casual      varchar(10),
    source_table       nvarchar(128)   -- satırın geldiği aylık tablo
);


-- 2) 12 aylık tabloyu dinamik SQL ile ekle
--    (boş metinler NULL'a çevrilir, baştaki/sondaki boşluklar silinir)
DECLARE @sql nvarchar(max) = N'';

SELECT @sql += N'
INSERT INTO dbo.divvy_2025 (ride_id, rideable_type, started_at, ended_at,
    start_station_name, start_station_id, end_station_name, end_station_id,
    start_lat, start_lng, end_lat, end_lng, member_casual, source_table)
SELECT
    NULLIF(LTRIM(RTRIM(ride_id)), N''''),
    NULLIF(LTRIM(RTRIM(rideable_type)), N''''),
    TRY_CONVERT(datetime2(3), started_at),
    TRY_CONVERT(datetime2(3), ended_at),
    NULLIF(LTRIM(RTRIM(start_station_name)), N''''),
    NULLIF(LTRIM(RTRIM(start_station_id)), N''''),
    NULLIF(LTRIM(RTRIM(end_station_name)), N''''),
    NULLIF(LTRIM(RTRIM(end_station_id)), N''''),
    TRY_CONVERT(float, start_lat),
    TRY_CONVERT(float, start_lng),
    TRY_CONVERT(float, end_lat),
    TRY_CONVERT(float, end_lng),
    NULLIF(LTRIM(RTRIM(member_casual)), N''''),
    N''' + t.name + N'''
FROM dbo.' + QUOTENAME(t.name) + N';
'
FROM sys.tables t
WHERE t.name LIKE N'2025[01][0-9]-divvy-tripdata%';

EXEC sp_executesql @sql;


-- 3) Doğrulama a: her ayın orijinal ve birleşik satır sayısı eşit olmalı (fark = 0)
SELECT o.name AS tablo,
       o.orijinal,
       ISNULL(b.birlesik, 0)              AS birlesik,
       o.orijinal - ISNULL(b.birlesik, 0) AS fark
FROM (
    SELECT t.name, SUM(p.rows) AS orijinal
    FROM sys.tables t
    JOIN sys.partitions p ON p.object_id = t.object_id AND p.index_id IN (0, 1)
    WHERE t.name LIKE N'2025[01][0-9]-divvy-tripdata%'
    GROUP BY t.name
) o
LEFT JOIN (
    SELECT source_table, COUNT(*) AS birlesik
    FROM dbo.divvy_2025
    GROUP BY source_table
) b ON b.source_table = o.name
ORDER BY o.name;


-- 4) Doğrulama b: dönüşümde bozulan satır var mı?
SELECT
    SUM(CASE WHEN started_at IS NULL OR ended_at IS NULL THEN 1 ELSE 0 END) AS tarih_null,
    SUM(CASE WHEN member_casual NOT IN ('member', 'casual')
               OR member_casual IS NULL THEN 1 ELSE 0 END)                  AS hatali_tip,
    COUNT(*) - COUNT(DISTINCT ride_id)                                      AS tekrar_eden_ride_id,
    COUNT(*)                                                                AS toplam_satir
FROM dbo.divvy_2025;
-- Sonuç: 5.552.994 satır, tüm aylarda fark = 0
