DROP DATABASE IF EXISTS TestDbA;
DROP DATABASE IF EXISTS TestDbB;

CREATE DATABASE TestDbA;
GO
USE TestDbA;
CREATE TABLE Person
(
  ID INT IDENTITY(1,1) PRIMARY KEY,
  [Name] NVARCHAR(50),
  Age INT
);
INSERT INTO Person
  ([Name], Age)
VALUES
  ('Bob', 40),
  ('Amy', 65);
GO
CREATE TABLE PersonNonAscii
(
  ID INT IDENTITY(1,1) PRIMARY KEY,
  [Name] NVARCHAR(50),
  Age INT
);
INSERT INTO PersonNonAscii
  ([Name], Age)
VALUES
  ('Very Long Name', 40),
  (N'Bøb', 40),
  -- New line
  ('Bob' + CHAR(10), 40),
  -- Zero width space
  (N'Bob' + NCHAR(8203) , 40);
GO

CREATE DATABASE TestDbB;
GO
USE TestDbB;
CREATE TABLE Car
(
  ID INT IDENTITY(1,1) PRIMARY KEY,
  Make NVARCHAR(50),
  PersonId INT
);
INSERT INTO Car
  (Make, PersonId)
Values
  ('Merc', 1),
  ('Ford', 1),
  ('Hyundai', 2);
