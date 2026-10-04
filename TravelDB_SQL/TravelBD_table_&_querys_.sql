/* =====================================================================
   TRAVEL MANAGEMENT DATABASE  (SQL Server / SSMS - T-SQL)
   Tables:  Customers -> Bookings <- TravelPackages <- Destinations

   RELATIONS
     Destinations   1 --- N  TravelPackages   SELECT COUNT(*) AS Customers_Rows FROM Customers;
     Customers      1 --- N  Bookings
     TravelPackages 1 --- N  Bookings
   ===================================================================== */


CREATE DATABASE TravelDB;
GO

USE TravelDB;
GO

/* ---------------------------------------------------------------------
   1. CUSTOMERS
   --------------------------------------------------------------------- */
CREATE TABLE Customers (
    CustomerId   INT IDENTITY(1,1) PRIMARY KEY,
    FullName     VARCHAR(100) NOT NULL,
    Email        VARCHAR(120) NOT NULL UNIQUE,
    Phone        VARCHAR(15)  NOT NULL,
    City         VARCHAR(60),
    CreatedAt    DATETIME DEFAULT GETDATE(),
    IsActive     BIT NOT NULL DEFAULT 1            -- soft delete flag
);
GO

/* ---------------------------------------------------------------------
   2. DESTINATIONS
   --------------------------------------------------------------------- */
CREATE TABLE Destinations (
    DestinationId   INT IDENTITY(1,1) PRIMARY KEY,
    Name            VARCHAR(100) NOT NULL,
    Country         VARCHAR(60)  NOT NULL,
    Category        VARCHAR(30)  NOT NULL,         -- Beach, Hill, City, Heritage, Adventure
    BestSeason      VARCHAR(30),
    Rating          DECIMAL(2,1) DEFAULT 0.0,
    CONSTRAINT chk_rating CHECK (Rating BETWEEN 0 AND 5)
);
GO

/* ---------------------------------------------------------------------
   3. TRAVEL PACKAGES  (FK -> Destinations)
   --------------------------------------------------------------------- */
CREATE TABLE TravelPackages (
    PackageId       INT IDENTITY(1,1) PRIMARY KEY,
    DestinationId   INT NOT NULL,
    PackageName     VARCHAR(120) NOT NULL,
    DurationDays    INT NOT NULL,
    PricePerPerson  DECIMAL(10,2) NOT NULL,
    MaxSeats        INT NOT NULL,
    StartDate       DATE NOT NULL,
    IsAvailable     BIT NOT NULL DEFAULT 1,
    CONSTRAINT fk_package_destination
        FOREIGN KEY (DestinationId) REFERENCES Destinations(DestinationId)
        ON DELETE NO ACTION ON UPDATE CASCADE,
    CONSTRAINT chk_duration CHECK (DurationDays > 0),
    CONSTRAINT chk_price    CHECK (PricePerPerson >= 0)
);
GO

/* ---------------------------------------------------------------------
   4. BOOKINGS  (FK -> Customers, FK -> TravelPackages)
   --------------------------------------------------------------------- */
CREATE TABLE Bookings (
    BookingId       INT IDENTITY(1,1) PRIMARY KEY,
    CustomerId      INT NOT NULL,
    PackageId       INT NOT NULL,
    BookingDate     DATETIME DEFAULT GETDATE(),
    NumTravelers    INT NOT NULL DEFAULT 1,
    TotalAmount     DECIMAL(12,2) NOT NULL,
    Status          VARCHAR(20) NOT NULL DEFAULT 'Pending',   -- Pending, Confirmed, Cancelled
    PaymentStatus   VARCHAR(20) NOT NULL DEFAULT 'Unpaid',    -- Unpaid, Paid, Refunded
    CONSTRAINT fk_booking_customer
        FOREIGN KEY (CustomerId) REFERENCES Customers(CustomerId)
        ON DELETE NO ACTION ON UPDATE CASCADE,
    CONSTRAINT fk_booking_package
        FOREIGN KEY (PackageId) REFERENCES TravelPackages(PackageId)
        ON DELETE NO ACTION ON UPDATE NO ACTION,
    CONSTRAINT chk_travelers CHECK (NumTravelers > 0),
    CONSTRAINT chk_status    CHECK (Status IN ('Pending','Confirmed','Cancelled')),
    CONSTRAINT chk_payment   CHECK (PaymentStatus IN ('Unpaid','Paid','Refunded'))
);
GO

/* Indexes for faster joins / searches */
-- CREATE INDEX idx_package_destination ON TravelPackages(DestinationId);
-- CREATE INDEX idx_booking_customer    ON Bookings(CustomerId);
-- CREATE INDEX idx_booking_package     ON Bookings(PackageId);
-- GO






---------------------------------------------------------------------------------------------------------------------------------------------


/* =====================================================================
   VIEW + STORED PROCEDURE
   (CREATE VIEW / PROCEDURE must be the first statement in a batch -> GO)
   ===================================================================== */
CREATE OR ALTER VIEW vw_BookingDetails AS
SELECT b.BookingId, c.CustomerId, c.FullName AS Customer, d.Name AS Destination,
       p.PackageName, b.NumTravelers, b.TotalAmount, b.Status, b.PaymentStatus
FROM Bookings b
JOIN Customers c      ON c.CustomerId = b.CustomerId
JOIN TravelPackages p ON p.PackageId  = b.PackageId
JOIN Destinations d   ON d.DestinationId = p.DestinationId;
GO

CREATE OR ALTER PROCEDURE sp_CreateBooking
    @CustomerId INT,
    @PackageId  INT,
    @Travelers  INT
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @Price DECIMAL(10,2);
    DECLARE @SeatsLeft INT;

    SELECT @Price = PricePerPerson FROM TravelPackages WHERE PackageId = @PackageId;

    SELECT @SeatsLeft = p.MaxSeats - ISNULL(SUM(CASE WHEN b.Status <> 'Cancelled' THEN b.NumTravelers END), 0)
    FROM TravelPackages p
    LEFT JOIN Bookings b ON b.PackageId = p.PackageId
    WHERE p.PackageId = @PackageId
    GROUP BY p.MaxSeats;

    IF @SeatsLeft IS NULL
        THROW 50001, 'Package not found', 1;

    IF @SeatsLeft < @Travelers
        THROW 50002, 'Not enough seats available', 1;

    INSERT INTO Bookings (CustomerId, PackageId, NumTravelers, TotalAmount)
    VALUES (@CustomerId, @PackageId, @Travelers, @Price * @Travelers);

    SELECT SCOPE_IDENTITY() AS NewBookingId;
END
GO

-- Test:   EXEC sp_CreateBooking @CustomerId = 2, @PackageId = 1, @Travelers = 3;
-- Test:   SELECT * FROM vw_BookingDetails;


/* =====================================================================
   ############  STOP - EVERYTHING ABOVE IS SETUP  ############
   Below are CRUD + JOIN queries. Highlight ONE query and press F5
   to run it (don't run the whole file again, it would repeat inserts).
   ===================================================================== */

/* ------------------------- CUSTOMERS -------------------------------- */
-- CREATE
INSERT INTO Customers (FullName, Email, Phone, City)
VALUES ('Neha Verma', 'neha@mail.com', '9900112233', 'Bengaluru');
-- READ
SELECT * FROM Customers WHERE IsActive = 1;
SELECT * FROM Customers WHERE CustomerId = 1;
SELECT * FROM Customers WHERE FullName LIKE '%Sharma%';
-- UPDATE
UPDATE Customers SET Phone = '9111111111', City = 'Thane' WHERE CustomerId = 1;
-- DELETE (soft)
UPDATE Customers SET IsActive = 0 WHERE CustomerId = 6;

/* ------------------------- DESTINATIONS ----------------------------- */
INSERT INTO Destinations (Name, Country, Category, BestSeason, Rating)
VALUES ('Kerala', 'India', 'Nature', 'Monsoon', 4.6);

SELECT * FROM Destinations ORDER BY Rating DESC;
SELECT * FROM Destinations WHERE Category = 'Beach';

UPDATE Destinations SET Rating = 4.8 WHERE DestinationId = 4;

DELETE FROM Destinations WHERE DestinationId = 6;   -- works only if no packages use it

/* ------------------------- TRAVEL PACKAGES -------------------------- */
INSERT INTO TravelPackages (DestinationId, PackageName, DurationDays, PricePerPerson, MaxSeats, StartDate)
VALUES (2, 'Manali Budget Trip', 4, 12000.00, 20, '2026-12-05');

SELECT p.PackageId, p.PackageName, d.Name AS Destination, p.DurationDays, p.PricePerPerson
FROM TravelPackages p
JOIN Destinations d ON d.DestinationId = p.DestinationId
WHERE p.IsAvailable = 1;

SELECT * FROM TravelPackages WHERE PricePerPerson BETWEEN 10000 AND 30000;

UPDATE TravelPackages SET PricePerPerson = 20000.00 WHERE PackageId = 1;
UPDATE TravelPackages SET IsAvailable = 0 WHERE PackageId = 6;
DELETE FROM TravelPackages WHERE PackageId = 7;

/* ------------------------- BOOKINGS --------------------------------- */
INSERT INTO Bookings (CustomerId, PackageId, NumTravelers, TotalAmount)
SELECT 3, PackageId, 2, PricePerPerson * 2
FROM TravelPackages WHERE PackageId = 1;

SELECT * FROM Bookings WHERE CustomerId = 1;

UPDATE Bookings SET Status = 'Confirmed', PaymentStatus = 'Paid' WHERE BookingId = 3;
UPDATE Bookings SET Status = 'Cancelled', PaymentStatus = 'Refunded' WHERE BookingId = 4;
DELETE FROM Bookings WHERE BookingId = 8;


/* =====================================================================
   JOIN / REPORT QUERIES
   ===================================================================== */

-- 1) FULL BOOKING DETAILS (4 tables)
SELECT b.BookingId, c.FullName AS Customer, d.Name AS Destination, p.PackageName,
       b.NumTravelers, b.TotalAmount, b.Status, b.PaymentStatus
FROM Bookings b
JOIN Customers c      ON c.CustomerId    = b.CustomerId
JOIN TravelPackages p ON p.PackageId     = b.PackageId
JOIN Destinations d   ON d.DestinationId = p.DestinationId
ORDER BY b.BookingDate DESC;

-- 2) A CUSTOMER'S TRIP HISTORY
SELECT c.FullName, d.Name AS Destination, p.PackageName, p.StartDate, b.Status
FROM Customers c
JOIN Bookings b       ON b.CustomerId = c.CustomerId
JOIN TravelPackages p ON p.PackageId  = b.PackageId
JOIN Destinations d   ON d.DestinationId = p.DestinationId
WHERE c.CustomerId = 1;

-- 3) REVENUE PER DESTINATION (paid only)

SELECT d.Name AS Destination,b.BookingId ,b.TotalAmount
FROM Destinations d
JOIN TravelPackages p ON p.DestinationId = d.DestinationId
JOIN Bookings b       ON b.PackageId     = p.PackageId

SELECT d.Name AS Destination, COUNT(b.BookingId) AS TotalBookings, SUM(b.TotalAmount) AS Revenue
FROM Destinations d
JOIN TravelPackages p ON p.DestinationId = d.DestinationId
JOIN Bookings b       ON b.PackageId     = p.PackageId
WHERE b.PaymentStatus = 'Paid'
GROUP BY d.DestinationId, d.Name
ORDER BY Revenue DESC;

-- 4) MOST POPULAR DESTINATION
SELECT TOP 1 d.Name, SUM(b.NumTravelers) AS TotalTravelers
FROM Bookings b
JOIN TravelPackages p ON p.PackageId = b.PackageId
JOIN Destinations d   ON d.DestinationId = p.DestinationId
WHERE b.Status <> 'Cancelled'
GROUP BY d.Name
ORDER BY TotalTravelers DESC;

-- 5) TOP SPENDING CUSTOMERS
SELECT c.FullName, c.City, SUM(b.TotalAmount) AS TotalSpent
FROM Customers c
JOIN Bookings b ON b.CustomerId = c.CustomerId
WHERE b.PaymentStatus = 'Paid'
GROUP BY c.CustomerId, c.FullName, c.City
ORDER BY TotalSpent DESC;

-- 6) SEATS LEFT PER PACKAGE
SELECT p.PackageId, p.PackageName, p.MaxSeats,
       ISNULL(SUM(CASE WHEN b.Status <> 'Cancelled' THEN b.NumTravelers END), 0) AS SeatsBooked,
       p.MaxSeats - ISNULL(SUM(CASE WHEN b.Status <> 'Cancelled' THEN b.NumTravelers END), 0) AS SeatsLeft
FROM TravelPackages p
LEFT JOIN Bookings b ON b.PackageId = p.PackageId
GROUP BY p.PackageId, p.PackageName, p.MaxSeats;

-- 7) PACKAGES NOBODY HAS BOOKED
SELECT p.PackageName, d.Name AS Destination
FROM TravelPackages p
JOIN Destinations d ON d.DestinationId = p.DestinationId
LEFT JOIN Bookings b ON b.PackageId = p.PackageId
WHERE b.BookingId IS NULL;

-- 8) PENDING PAYMENTS (follow-up list)
SELECT c.FullName, c.Phone, p.PackageName, b.TotalAmount
FROM Bookings b
JOIN Customers c      ON c.CustomerId = b.CustomerId
JOIN TravelPackages p ON p.PackageId  = b.PackageId
WHERE b.PaymentStatus = 'Unpaid' AND b.Status = 'Pending';

-- 9) RECOMMENDATIONS: same-category packages the customer hasn't booked
SELECT DISTINCT p2.PackageName, d2.Name AS Destination, d2.Category, p2.PricePerPerson
FROM Bookings b
JOIN TravelPackages p1 ON p1.PackageId = b.PackageId
JOIN Destinations d1   ON d1.DestinationId = p1.DestinationId
JOIN Destinations d2   ON d2.Category = d1.Category
JOIN TravelPackages p2 ON p2.DestinationId = d2.DestinationId
WHERE b.CustomerId = 1
  AND p2.PackageId NOT IN (SELECT PackageId FROM Bookings WHERE CustomerId = 1);