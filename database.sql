CREATE DATABASE Conferences;

CREATE TABLE Conferences (
	ConferenceID int not null primary key identity (1,1),
	ConferenceName nvarchar(60) not null,
	Address nvarchar(50) not null,
	City nvarchar(40) not null,
	PostalCode nvarchar (10) not null,
	StartDate date not null,
	EndDate date not null ,
)

ALTER TABLE Conferences WITH CHECK ADD CONSTRAINT [StartDateBeforeEndDate] 
CHECK ((StartDate<=EndDate))

CREATE TABLE ConferenceDays (
	DayID int not null primary key identity(1,1),
	ConferenceID int not null foreign key references Conferences(ConferenceID),
	Date date not null,
	MaxPeople int not null CHECK (MaxPeople>=0),			
)

CREATE TABLE Prices (
	PriceID int not null primary key identity(1,1),
	DayID int null foreign key references ConferenceDays(DayID),   		
	Price numeric(2,2) not null CHECK (Price>0),								
	DaysTo int not null CHECK (DaysTo>0),
	Discount numeric(2,2) not null DEFAULT 0 CHECK (DISCOUNT BETWEEN 0 AND 1),		
	StudentDiscount numeric(2,2) not null DEFAULT 0 CHECK (StudentDiscount BETWEEN 0 AND 1),
)

ALTER TABLE Prices WITH CHECK ADD CONSTRAINT [SumDiscountsBetween0And1] 
CHECK ((Discount+StudentDiscount<=1))

CREATE TABLE Workshops (
	WorkshopID int not null primary key identity(1,1),
	WorkshopName nvarchar (60) not null,
	DayID int not null foreign key references ConferenceDays(DayID),
	StartTime time(0) not null,									
	EndTime time(0) not null,		 					
	MaxPeople int not null CHECK (MaxPeople>=0),  			
	PriceID int null foreign key references Prices(PriceID), 
)

ALTER TABLE Workshops WITH CHECK ADD CONSTRAINT [StartTimeBeforeEndTime] 
CHECK ((StartTime<EndTime))

CREATE TABLE Clients (
	ClientID int not null primary key identity(1,1),
	Company bit not null DEFAULT(0), 								
	CompanyName nvarchar(40) null,
	LastName nvarchar(25) null,
	FirstName nvarchar(25) null,
	Address nvarchar(50) null,
	City nvarchar(40) null,
	PostalCode nvarchar(10) null,
	Phone nvarchar(15) not null CHECK(ISNUMERIC(Phone)=1),
)

ALTER TABLE Clients WITH CHECK ADD CONSTRAINT [CompanyAndCompanyName]
CHECK ((Company=1 AND CompanyName IS NOT NULL) OR (Company=0 AND CompanyName IS NULL))

CREATE TABLE Participants (
	ParticipantID int not null primary key identity(1,1),
	ClientID int not null foreign key references Clients(ClientID),
	LastName nvarchar(25) not null,
	FirstName nvarchar(25) not null,
	Phone nvarchar(15) not null CHECK(ISNUMERIC(Phone)=1),	
	Student bit not null DEFAULT(0),
	StudentIDNo int null,
)

ALTER TABLE Participants WITH CHECK ADD CONSTRAINT [OnlyStudentWithIDNo] 
CHECK ((Student=1 AND StudentIDNo IS NOT NULL) OR (Student=0 AND StudentIDNo IS NULL))

CREATE TABLE ConferenceReservations (
	ConfResID int not null primary key identity(1,1),
	DayID int not null foreign key references ConferenceDays(DayID),
	ClientID int not null foreign key references Clients(ClientID),
	ResDate date not null DEFAULT GETDATE(),
	NoOfParticipants int not null CHECK (NoOfParticipants>0),
	NoOfStudents int not null CHECK (NoOfStudents>=0),			
	Cancelled bit not null DEFAULT(0),
)

ALTER TABLE ConferenceReservations WITH CHECK ADD CONSTRAINT [StudentsNotGreaterThanParticipants]
CHECK ((NoOfStudents<=NoOfParticipants))

CREATE TABLE ConfDayRegistrations (   				
	RegistrationID int not null primary key identity(1,1),
	ReservationID int not null foreign key references ConferenceReservations(ConfResID),
	ParticipantID int not null foreign key references Participants(ParticipantID),
)

CREATE TABLE WorkshopReservations (
	WorkResID int not null primary key identity(1,1),
	WorkshopID int not null foreign key references Workshops(WorkshopID),
	DayRegID int not null foreign key references ConfDayRegistrations(RegistrationID),
	ResDate date not null DEFAULT GETDATE(),
	Cancelled bit not null DEFAULT(0),
) 

CREATE TABLE WorkshopRegistrations (
	RegistrationID int not null primary key identity(1,1),
	ReservationID int not null foreign key references WorkshopReservations(WorkResID),
)

CREATE TABLE Payments (
	PaymentID int not null primary key identity(1,1),
	ClientID int not null foreign key references Clients(ClientID),
	ConfResID int null foreign key references ConferenceReservations(ConfResID),
	WorkResID int null foreign key references WorkshopReservations(WorkResID),
	Paid numeric(2,2) null CHECK (Paid>0),
	PayDate date null DEFAULT GETDATE(),
)

ALTER TABLE PAYMENTS WITH CHECK ADD CONSTRAINT [ConferenceOrWorkshop]
CHECK ((WorkResID IS NULL AND ConfResID IS NOT NULL) OR (WorkResID IS NOT NULL AND ConfResID IS NULL))
GO	

CREATE VIEW MostPopularConferences
AS
SELECT TOP 100 c.ConferenceName, c.Address, c.City, c.startDate, c.endDate, (SUM(cr.NoOfParticipants)/(DATEDIFF(day,c.StartDate,c.EndDate)+1)) AS AverageParticipantsPerDay
FROM Conferences c INNER JOIN ConferenceDays cd ON c.ConferenceID=cd.ConferenceID
INNER JOIN ConferenceReservations cr ON cd.DayID=cr.DayID AND cr.Cancelled=0
GROUP BY c.ConferenceID, c.ConferenceName, c.Address, c.City, c.startDate, c.endDate
ORDER BY AverageParticipantsPerDay DESC
GO

CREATE VIEW MostPopularWorkshops
AS
SELECT TOP 100 w.WorkshopName, c.ConferenceName, cd.Date, COUNT(wr.WorkResID) AS Participants
FROM Conferences c INNER JOIN ConferenceDays cd ON c.ConferenceID=cd.ConferenceID
INNER JOIN Workshops w ON w.DayID=cd.DayID
INNER JOIN WorkshopReservations wr ON wr.WorkshopID=w.WorkshopID AND wr.Cancelled=0
GROUP BY w.WorkshopID,w.WorkshopName, c.ConferenceName, cd.Date
ORDER BY Participants DESC
GO

CREATE VIEW AvailableDays
AS
SELECT c.ConferenceName, c.Address, c.City, cd.Date, cd.MaxPeople,(cd.MaxPeople-SUM(cr.NoOfParticipants)) AS FreePlaces 
FROM Conferences c INNER JOIN ConferenceDays cd ON c.conferenceID=cd.conferenceID AND cd.Date>=GETDATE()
INNER JOIN ConferenceReservations cr ON cd.dayID=cr.DayID AND cr.Cancelled=0
GROUP BY cr.DayID, c.ConferenceName,c.Address, c.City, cd.Date,cd.MaxPeople
GO

CREATE VIEW AvailableWorkshops
AS
SELECT w.WorkshopName, c.ConferenceName, c.Address, c.City, cd.Date, w.MaxPeople,(w.MaxPeople-COUNT(wr.WorkResID)) AS FreePlaces
FROM Conferences c INNER JOIN ConferenceDays cd ON c.ConferenceID=cd.ConferenceID AND cd.Date>=GETDATE()
INNER JOIN Workshops w ON w.DayID=cd.DayID
INNER JOIN WorkshopReservations wr ON wr.WorkshopID=w.WorkshopID AND wr.Cancelled=0
GROUP BY w.WorkshopName, c.ConferenceName, c.Address, c.City, cd.Date, w.MaxPeople
GO
		
CREATE VIEW UnpaidConferenceReservations				 
AS
SELECT DISTINCT cl.CompanyName, cl.LastName,cl.FirstName, cl.Phone, c.ConferenceName, cd.Date, (7-DATEDIFF(day,cr.ResDate,GETDATE())) AS DaysLeft
FROM Conferences c INNER JOIN ConferenceDays cd ON c.ConferenceID=cd.ConferenceID
INNER JOIN Prices pr ON cd.DayID=pr.DayID 
INNER JOIN ConferenceReservations cr ON cd.DayID=cr.DayID AND cr.Cancelled=0
INNER JOIN Clients cl ON cr.ClientID=cl.ClientID
LEFT OUTER JOIN Payments p ON p.ClientID=cl.ClientID
WHERE p.PaymentID IS NULL OR p.Paid<((cr.NoOfParticipants-cr.NoOfStudents)*(pr.Price*(1-pr.Discount))+cr.NoOfStudents*(pr.Price*(1-pr.Discount-pr.StudentDiscount)))
AND pr.DaysTo=(SELECT TOP 1 pri.DaysTo FROM Prices pri WHERE pri.DayID=pr.DayID AND DATEDIFF(day,cr.ResDate,cd.Date)>=pri.DaysTo ORDER BY pri.DaysTo)
GO

CREATE VIEW UnpaidWorkshopReservations			
AS
SELECT DISTINCT p.LastName,p.FirstName, p.Phone, w.WorkshopName, c.ConferenceName, cd.Date, (7-DATEDIFF(day,wr.ResDate,GETDATE())) AS DaysLeft
FROM Conferences c INNER JOIN ConferenceDays cd ON c.ConferenceID=cd.ConferenceID
INNER JOIN Workshops w ON cd.DayID=w.DayID
INNER JOIN Prices pr ON w.PriceID=pr.PriceID
INNER JOIN ConferenceReservations cr ON cd.DayID=cr.DayID AND cr.Cancelled=0
INNER JOIN ConfDayRegistrations cdr ON cr.ConfResID=cdr.ReservationID
INNER JOIN WorkshopReservations wr ON cdr.RegistrationID=wr.DayRegID
INNER JOIN Participants p ON cdr.ParticipantID=p.ParticipantID
LEFT OUTER JOIN Payments pay ON pay.ClientID=p.ParticipantID
WHERE pay.PaymentID IS NULL OR pay.Paid<pr.Price
GO

CREATE VIEW ClientsHistory
AS
SELECT cl.CompanyName, cl.LastName, cl.FirstName, COUNT(cr.ConfResID) AS DaysReservations, SUM(cr.NoOfParticipants) AS SumParticipants, COUNT(cr.Cancelled) AS CancelledReservations
FROM Clients cl INNER JOIN ConferenceReservations cr ON cl.ClientID=cr.ClientID
GROUP BY cl.CompanyName, cl.LastName, cl.FirstName, cr.Cancelled
GO

CREATE VIEW BestClients
AS
SELECT TOP 100 cl.CompanyName, cl.LastName, cl.FirstName, COUNT(cr.ConfResID) AS DaysReservations, SUM(cr.NoOfParticipants) AS Participants
FROM Clients cl INNER JOIN ConferenceReservations cr ON cl.ClientID=cr.ClientID AND cr.Cancelled=0
GROUP BY cl.CompanyName, cl.LastName, cl.FirstName, cr.Cancelled
ORDER BY Participants,DaysReservations DESC
GO

CREATE VIEW CancelledConferenceReservations
AS
SELECT cl.ClientID, cr.ConfResID, c.ConferenceName, cd.Date, cr.NoOfParticipants
FROM Conferences c INNER JOIN ConferenceDays cd ON c.ConferenceID=cd.ConferenceID
INNER JOIN ConferenceReservations cr ON cd.DayID=cr.DayID AND cr.Cancelled=1
INNER JOIN Clients cl ON cr.ClientID=cl.ClientID
GO

CREATE VIEW CancelledWorkshopReservations
AS
SELECT p.ParticipantID, wr.WorkResID, c.ConferenceName, w.WorkshopName, cd.Date
FROM Conferences c INNER JOIN ConferenceDays cd ON c.ConferenceID=cd.ConferenceID
INNER JOIN ConferenceReservations cr ON cd.DayID=cr.DayID
INNER JOIN ConfDayRegistrations cdr ON cr.ConfResID=cdr.ReservationID
INNER JOIN WorkshopReservations wr ON cdr.RegistrationID=wr.DayRegID AND wr.Cancelled=1
INNER JOIN Workshops w ON wr.WorkshopID=wr.WorkshopID
INNER JOIN Participants p ON cdr.ParticipantID=p.ParticipantID
GO

CREATE VIEW ConferenceDaysReservedButNotRegistered
AS
SELECT c.ConferenceName, cd.Date, cl.CompanyName, cl.LastName, cl.FirstName, DATEDIFF(day,GETDATE(),c.StartDate) AS DaysLeftForRegistration, cr.NoOfParticipants, COUNT (cdr.RegistrationID) AS RegisteredNow
FROM Conferences c INNER JOIN ConferenceDays cd ON c.ConferenceID=cd.ConferenceID
INNER JOIN ConferenceReservations cr ON cd.DayID=cr.DayID
INNER JOIN Clients cl ON cr.clientID=cl.ClientID
LEFT OUTER JOIN ConfDayRegistrations cdr ON cr.ConfResID=cdr.ReservationID
WHERE (SELECT COUNT(cdr2.RegistrationID) FROM ConfDayRegistrations cdr2 WHERE cdr.RegistrationID=cdr2.RegistrationID)<cr.NoOfParticipants
GROUP BY c.ConferenceName, cd.Date, cl.CompanyName, cl.LastName, cl.FirstName, c.StartDate,cr.NoOfParticipants
GO

CREATE VIEW UpcomingConfDaysPrices
AS
SELECT c.ConferenceName, cd.Date, p.Price, p.DaysTo, p.Discount, p.StudentDiscount
FROM Conferences c INNER JOIN ConferenceDays cd ON c.ConferenceID=cd.ConferenceID
INNER JOIN Prices p ON p.DayID=cd.DayID
WHERE p.DaysTo<DATEDIFF(day,GETDATE(),cd.Date)
GO

CREATE VIEW OverpaidConferences   
AS
SELECT c.ConferenceName,cd.Date,cl.ClientID,cl.CompanyName,cl.LastName,cl.FirstName,cl.Phone,
(pay.Paid-(cr.NoOfParticipants-cr.NoOfStudents)*(p.Price*(1-p.Discount))+cr.NoOfStudents*(p.Price*(1-p.Discount-p.StudentDiscount))) AS Difference
FROM Conferences c INNER JOIN ConferenceDays cd ON c.ConferenceID=cd.ConferenceID
INNER JOIN ConferenceReservations cr ON cd.DayID=cr.DayID
INNER JOIN Clients cl ON cr.ClientID=cl.ClientID
INNER JOIN Prices p ON p.DayID=cd.DayID AND p.DaysTo=(SELECT TOP 1 pri.DaysTo FROM Prices pri WHERE pri.DayID=p.DayID AND DATEDIFF(day,cr.ResDate,cd.Date)>=pri.DaysTo ORDER BY pri.DaysTo)
INNER JOIN Payments pay ON cr.ConfResID=pay.ConfResID AND cl.ClientID=pay.ClientID
WHERE (pay.Paid-(cr.NoOfParticipants-cr.NoOfStudents)*(p.Price*(1-p.Discount))+cr.NoOfStudents*(p.Price*(1-p.Discount-p.StudentDiscount)))>0
GO

CREATE VIEW OverpaidWorkshops
AS
SELECT c.ConferenceName, w.WorkshopName,cd.Date,p.ParticipantID,p.LastName,p.FirstName,p.Phone, (pay.Paid-pr.Price) AS Difference
FROM Conferences c INNER JOIN ConferenceDays cd ON c.ConferenceID=cd.ConferenceID
INNER JOIN ConferenceReservations cr ON cd.DayID=cr.DayID AND cr.Cancelled=0
INNER JOIN ConfDayRegistrations cdr ON cr.ConfResID=cdr.ReservationID
INNER JOIN WorkshopReservations wr ON cdr.RegistrationID=wr.DayRegID AND wr.Cancelled=0
INNER JOIN Workshops w ON wr.WorkshopID=w.WorkshopID
INNER JOIN Participants p ON cdr.ParticipantID=p.ParticipantID
INNER JOIN Prices pr ON w.PriceID=pr.PriceID
INNER JOIN Payments pay ON pay.WorkResID=wr.WorkResID
WHERE (pay.Paid-pr.Price)>0
GO

CREATE VIEW CurrentReservationsRegisteredParticipants			
AS
SELECT cl.ClientID, cl.CompanyName, cl.Firstname, cl.Lastname, cr.ConfResID, c.ConferenceName, cd.Date, cr.NoOfParticipants, COUNT(cdr.RegistrationID) AS Registered
FROM Conferences c INNER JOIN ConferenceDays cd ON c.ConferenceID=cd.ConferenceID AND cd.Date>=GETDATE()
INNER JOIN ConferenceReservations cr ON cd.DayID=cr.DayID AND Cancelled=0
INNER JOIN ConfDayRegistrations cdr ON cr.ConfResID=cdr.ReservationID
INNER JOIN Clients cl ON cr.ClientID=cl.ClientID
GROUP BY cl.ClientID, cl.CompanyName, cl.Firstname, cl.Lastname, cr.ConfResID, c.ConferenceName, cd.Date, cr.NoOfParticipants
GO

CREATE PROCEDURE AddConferenceDay
	@ConferenceID int,
	@Date date,
	@MaxPeople int
AS
BEGIN
	INSERT INTO ConferenceDays(
		ConferenceID, Date, MaxPeople
	)
	VALUES(
		@ConferenceID, @Date, @MaxPeople
	)
END
GO

CREATE PROCEDURE AddConference
	@ConferenceName nvarchar(60),
	@Address nvarchar (50),
	@City nvarchar(40),
	@PostalCode nvarchar(10),
	@StartDate date,
	@EndDate date,
	@MaxPeople int
AS
BEGIN
	SET NOCOUNT ON;
	IF (@StartDate<GETDATE())
	BEGIN
		RAISERROR('Conference can''t start in the past',14,1)
		RETURN
	END
	INSERT INTO Conferences(
		ConferenceName, Address, City, PostalCode, StartDate, EndDate
	)
	VALUES(
		@ConferenceName, @Address, @City, @PostalCode, @StartDate, @EndDate
	)
	DECLARE @ConferenceID int
	SET @ConferenceID=@@IDENTITY
	DECLARE @i int
	SET @i=0
	DECLARE @d date
	WHILE @i<=DATEDIFF(day,@StartDate,@EndDate)
	BEGIN
		SET @d=DATEADD(day,@i,@StartDate)
		EXEC AddConferenceDay
			@ConferenceID, 
			@d, 
			@MaxPeople
		SET @i=@i+1
	END
END
GO

CREATE PROCEDURE AddPrice
	@DayID int,
	@Price numeric(2,2),
	@DaysTo int,
	@Discount numeric(2,2),
	@StudentDiscount numeric (2,2)
AS
BEGIN
	
	SET NOCOUNT ON;
	INSERT INTO Prices(
		Price,DaysTo,Discount,StudentDiscount, DayID
	)
	VALUES(
		@Price,@DaysTo,@Discount,@StudentDiscount,@DayID
	)
END
GO

CREATE PROCEDURE AddWorkshop
	@WorkshopName nvarchar(60),
	@DayID int ,
	@StartTime time,
	@EndTime time,
	@MaxPeople int,
	@PriceID int
AS
BEGIN 
	SET NOCOUNT ON;
	INSERT INTO Workshops(
		WorkshopName,DayID,StartTime,EndTime,MaxPeople,PriceID
	)
	VALUES (
		@WorkshopName, @DayID, @StartTime, @EndTime, @MaxPeople, @PriceID
	)
END
GO

CREATE PROCEDURE AddClient
	@Company bit,
	@CompanyName nvarchar(40),
	@LastName nvarchar(25),
	@FirstName nvarchar(25),
	@Address nvarchar(50),
	@City nvarchar(40),
	@PostalCode nvarchar(10),
	@Phone nvarchar(15)
AS
BEGIN
	SET NOCOUNT ON;
	INSERT INTO Clients(
		Company,CompanyName,LastName,FirstName,Address,City,PostalCode,Phone
	)
	VALUES(
		@Company,@CompanyName,@LastName,@FirstName,@Address,@City,@PostalCode,@Phone
	)
END	
GO

CREATE PROCEDURE AddParticipant
	@ClientID int,
	@LastName nvarchar(25),
	@Firstname nvarchar(25),
	@Phone nvarchar(15),
	@Student bit,
	@StudentIDNo integer
AS
BEGIN
	SET NOCOUNT ON;
	INSERT INTO Participants(
		ClientID, LastName, FirstName, Phone, Student, StudentIDNo
	)
	VALUES(
		@ClientID, @LastName, @FirstName, @Phone, @Student, @StudentIDNo
	)	
END
GO
		
		
CREATE PROCEDURE MakeConfDayReservation
	@DayID int,
	@ClientID int,
	@NoOfParticipants int,
	@NoOfStudents int
AS
BEGIN
	IF GETDATE()>(SELECT Date FROM ConferenceDays WHERE DayID=@DayID)
	BEGIN
		RAISERROR('Can''t make reservation for past conference day',14,1)
		RETURN
	END
	SET NOCOUNT ON;
	INSERT INTO ConferenceReservations(
		DayID, ClientID, NoOfParticipants,NoOfStudents
	)
	VALUES (
		@DayID, @ClientID, @NoOfParticipants,@NoOfStudents
	)
END
GO

CREATE PROCEDURE MakeConferenceReservation
	@ConferenceID int,
	@ClientID int,
	@NoOfParticipants int,
	@NoOfStudents int
AS
BEGIN
	IF GETDATE()>(SELECT StartDate FROM Conferences WHERE ConferenceID=@ConferenceID)
	BEGIN
		RAISERROR('Can''t make reservation for past conference',14,1)
		RETURN
	END
	SET NOCOUNT ON;
	DECLARE @i int
	SET @i=0
	WHILE @i<=DATEDIFF(day,(SELECT StartDate FROM Conferences WHERE ConferenceID=@ConferenceID),(SELECT EndDate FROM Conferences WHERE ConferenceID=@ConferenceID))
	BEGIN
		DECLARE @DayID int 
		SET @DayID = (SELECT DayID FROM ConferenceDays cd INNER JOIN Conferences c ON cd.ConferenceID=c.ConferenceID
						WHERE c.ConferenceID=@ConferenceID AND cd.Date=DATEADD(day,@i,c.StartDate))
		EXECUTE MakeConfDayReservation
			@DayID,
			@ClientID,
			@NoOfParticipants,
			@NoOfStudents
		SET @i=@i+1
	END
END
GO

CREATE PROCEDURE RegisterToConferenceDay
	@ReservationID int,
	@ParticipantID int,
	@ClientID int,
	@LastName nvarchar(25),
	@Firstname nvarchar(25),
	@Student bit,
	@StudentIDNo integer
AS
BEGIN
	IF ((SELECT cr.Cancelled FROM ConfDayRegistrations cdr INNER JOIN ConferenceReservations cr
							ON cdr.ReservationID=cr.ConfResID WHERE cr.ConfResID=@ReservationID)=1)
	BEGIN
		RAISERROR ('Can''t register. Reservation was cancelled.',14,1)
		RETURN
	END
	SET NOCOUNT ON;
	IF (@ParticipantID IS NULL)
	BEGIN
		EXECUTE AddParticipant
			@ClientID,
			@LastName,
			@Firstname,
			@Student,
			@StudentIDNo
			SET @ParticipantID=@@IDENTITY
	END
	INSERT INTO ConfDayRegistrations (
		ReservationID, ParticipantID
	)
	VALUES (
		@ReservationID, @ParticipantID
	)
END
GO

CREATE PROCEDURE MakeWorkshopReservation
	@WorkshopID int,
	@DayRegID int
AS
BEGIN
	IF GETDATE()>(SELECT cd.Date FROM Workshops w INNER JOIN ConferenceDays cd ON w.DayID=cd.DayID WHERE WorkshopID=@WorkshopID)
	BEGIN
		RAISERROR('Can''t make reservation for past workshop',14,1)
		RETURN
	END
	SET NOCOUNT ON;
	INSERT INTO WorkshopReservations (
		WorkshopID, DayRegID
	)
	VALUES (
		@WorkshopID, @DayRegID
	)
END
GO

CREATE PROCEDURE RegisterToWorkshop 
	@ReservationID int
AS
BEGIN
	IF (SELECT wr.Cancelled FROM WorkshopReservations wr INNER JOIN Workshops w
						ON wr.WorkshopID=w.WorkshopID WHERE wr.WorkResID=@ReservationID)=1
	BEGIN
		RAISERROR ('Can''t register. Reservation was cancelled',14,1)
		RETURN
	END
	SET NOCOUNT ON;
	INSERT INTO WorkshopRegistrations (
		ReservationID
	)
	VALUES (
		@ReservationID
	)
END
GO

CREATE PROCEDURE MakeConfResPayment 
	@ClientID int,
	@ConfResID int,
	@Paid numeric(2,2)
AS
BEGIN
	SET NOCOUNT ON;
	INSERT INTO Payments(
		ClientID, ConfResID, Paid
	)
	VALUES (
		@ClientID, @ConfResID, @Paid
	)
END
GO

CREATE PROCEDURE MakeWorkResPayment 
	@ClientID int,
	@WorkResID int,
	@Paid numeric(2,2)
AS
BEGIN
	SET NOCOUNT ON;
	INSERT INTO Payments(
		ClientID, WorkResID, Paid
	)
	VALUES (
		@ClientID, @WorkResID, @Paid
	)
END
GO

CREATE PROCEDURE PayForWholeReservation 
	@ClientID int,
	@ConfResID int
AS
BEGIN 
	SET NOCOUNT ON;
	DECLARE @Paid int
	SET @Paid=(
				SELECT (p.Price*(cr.NoOfParticipants-cr.NoOfStudents)*(1-Discount)+p.Price*cr.NoOfStudents*(1-StudentDiscount-Discount)) FROM 
				Clients cl INNER JOIN ConferenceReservations cr ON cl.ClientID=cr.ClientID
				INNER JOIN ConferenceDays cd ON cr.DayID=cd.DayID
				INNER JOIN Prices p ON p.DayID=cd.DayID
				WHERE ConfResID=@ConfResID AND p.DaysTo=(SELECT TOP 1 DaysTo FROM Prices WHERE DATEDIFF(day,cr.ResDate,cd.Date)>=DaysTo ORDER BY DaysTo)
				)
	INSERT INTO Payments(
		ClientID, ConfResID, Paid
	)
	VALUES (
		@ClientID, @ConfResID, @Paid
	)
END
GO

CREATE PROCEDURE GenerateIdentifiers									
	@ConferenceID int
AS
BEGIN
	SELECT DISTINCT (CONVERT(nvarchar(8),p.ParticipantID)+': '+p.FirstName+' '+p.LastName+', '+cl.CompanyName) AS Identifier
	FROM ConferenceDays cd INNER JOIN ConferenceReservations cr ON cd.DayID=cr.DayID AND Cancelled=0
	INNER JOIN ConfDayRegistrations cdr ON cr.ConfResID=cdr.ReservationID
	INNER JOIN Clients cl ON cr.ClientID=cl.ClientID
	INNER JOIN Participants p ON cl.ClientID=p.ClientID
	INNER JOIN ConfDayRegistrations cdr2 ON p.ParticipantID=cdr2.ParticipantID
	WHERE cd.ConferenceID=@ConferenceID AND cl.Company=1
	UNION
	SELECT DISTINCT (CONVERT(nvarchar(8),p.ParticipantID)+': '+p.FirstName+' '+p.LastName) AS Identifier
	FROM ConferenceDays cd INNER JOIN ConferenceReservations cr ON cd.DayID=cr.DayID AND Cancelled=0
	INNER JOIN ConfDayRegistrations cdr ON cr.ConfResID=cdr.ReservationID
	INNER JOIN Clients cl ON cr.ClientID=cl.ClientID
	INNER JOIN Participants p ON cl.ClientID=p.ClientID
	INNER JOIN ConfDayRegistrations cdr2 ON p.ParticipantID=cdr2.ParticipantID
	WHERE cd.ConferenceID=@ConferenceID AND cl.Company=0
END
GO

CREATE PROCEDURE MyConferences
	@ParticipantID int 
AS
BEGIN
	SELECT c.ConferenceName,c.Address,c.City,c.PostalCode,cd.Date
	FROM Conferences c INNER JOIN ConferenceDays cd ON c.ConferenceID=cd.ConferenceID
	INNER JOIN ConferenceReservations cr ON cd.DayID=cr.DayID AND cr.Cancelled=0
	INNER JOIN ConfDayRegistrations cdr ON cr.ConfResID=cdr.ReservationID
	INNER JOIN Participants p ON cdr.ParticipantID=p.ParticipantID
	INNER JOIN Prices pr ON cd.DayID=pr.DayID 
	AND pr.DaysTo=(SELECT TOP 1 pr2.DaysTo FROM Prices pr2 WHERE pr2.DayID=pr.DayID AND DATEDIFF(day,cr.ResDate,cd.Date)>=pr2.DaysTo ORDER BY pr2.DaysTo)
	INNER JOIN Payments pay ON pay.ConfResID=cr.ConfResID
	WHERE p.ParticipantID=@ParticipantID
END
GO

CREATE PROCEDURE MyWorkshops
	@ParticipantID int
AS
BEGIN
	SELECT w.WorkshopName, c.ConferenceName, c.Address, c.City,c.PostalCode,cd.Date,w.StartTime,w.EndTime
	FROM Conferences c INNER JOIN ConferenceDays cd ON c.ConferenceID=cd.ConferenceID
	INNER JOIN ConferenceReservations cr ON cd.DayID=cr.DayID AND cr.Cancelled=0
	INNER JOIN ConfDayRegistrations cdr ON cr.ConfResID=cdr.ReservationID
	INNER JOIN WorkshopReservations wr ON cdr.RegistrationID=wr.DayRegID AND wr.Cancelled=0
	INNER JOIN Workshops w ON wr.WorkshopID=w.WorkshopID
	INNER JOIN WorkshopRegistrations wreg ON wr.WorkResID=wreg.ReservationID
	INNER JOIN Participants p ON cdr.ParticipantID=p.ParticipantID
	INNER JOIN Prices pr ON w.PriceID=pr.PriceID
	INNER JOIN Payments pay ON pay.WorkResID=wr.WorkResID
	WHERE p.ParticipantID=@ParticipantID
END
GO

CREATE PROCEDURE ConferenceDayList
	@DayID int
AS
BEGIN
	SELECT p.ParticipantID,p.LastName,p.FirstName
	FROM ConferenceDays cd INNER JOIN ConferenceReservations cr ON cd.DayID=cr.DayID AND cr.Cancelled=0
	INNER JOIN ConfDayRegistrations cdr ON cr.ConfResID=cdr.ReservationID
	INNER JOIN Participants p ON cdr.ParticipantID=p.ParticipantID
	WHERE @DayID=cd.DayID
END
GO

CREATE PROCEDURE WorkshopList
	@WorkshopID int
AS
BEGIN
	SELECT p.ParticipantID,p.LastName,p.FirstName
	FROM WorkshopReservations wr 
	INNER JOIN WorkshopRegistrations wreg ON wr.WorkResID=wreg.ReservationID AND wr.Cancelled=0
	INNER JOIN ConfDayRegistrations cdr ON wr.DayRegID=cdr.RegistrationID
	INNER JOIN Participants p ON cdr.ParticipantID=p.ParticipantID
	WHERE @WorkshopID=wr.WorkshopID
END
GO

CREATE PROCEDURE ClientConfPayments
	@ClientID int
AS
BEGIN
	SELECT c.ConferenceName, cd.Date, cr.NoOfParticipants, cr.NoOfStudents, 
	((cr.NoOfParticipants-cr.NoOfStudents)*(p.Price*(1-p.Discount))+cr.NoOfStudents*(p.Price*(1-p.Discount-p.StudentDiscount))) AS ToPay,pay.Paid
	FROM Clients cl INNER JOIN ConferenceReservations cr ON cl.ClientID=cr.ClientID
	INNER JOIN ConferenceDays cd ON cr.DayID=cd.DayID
	INNER JOIN Conferences c ON cd.ConferenceID=c.ConferenceID
	INNER JOIN Prices p ON p.DayID=cd.DayID 
	AND p.DaysTo=(SELECT TOP 1 pr.DaysTo FROM Prices pr WHERE pr.DayID=p.DayID AND DATEDIFF(day,cr.ResDate,cd.Date)>=pr.DaysTo ORDER BY pr.DaysTo)
	LEFT OUTER JOIN Payments pay ON cr.ConfResID=pay.ConfResID
	WHERE cl.ClientID=@ClientID
END
GO

CREATE PROCEDURE ChangeConferenceDayPlaces
	@ConferenceDayID int,
	@NewMaxPeople int
AS
BEGIN
	SET NOCOUNT ON;
	IF NOT EXISTS
		(SELECT * FROM ConferenceDays WHERE @ConferenceDayID=DayID)
	BEGIN
		RAISERROR ('No conference day with given ID',14,1)
		RETURN
	END
	IF (@NewMaxPeople<(SELECT SUM(NoOfParticipants) FROM ConferenceReservations cr 
						INNER JOIN ConferenceDays cd ON cr.DayID=cd.DayID WHERE cd.DayID=@ConferenceDayID))
	BEGIN
		RAISERROR ('Number of reserved places is bigger than new participants limit',14,1)
		RETURN
	END
	UPDATE ConferenceDays
		SET MaxPeople=@NewMaxPeople
		WHERE DayID=@ConferenceDayID
END
GO

CREATE PROCEDURE ChangeWorkshopPlaces
	@WorkshopID int,
	@NewMaxPeople int
AS
BEGIN
	SET NOCOUNT ON;
	IF NOT EXISTS
		(SELECT * FROM Workshops WHERE @WorkshopID=WorkshopID)
	BEGIN
		RAISERROR ('No workshop with given ID',14,1)
		RETURN
	END
	IF (@NewMaxPeople<(SELECT COUNT(WorkResID) FROM WorkshopReservations wr
						INNER JOIN Workshops w ON w.WorkshopID=wr.WorkshopID WHERE w.WorkshopID=@WorkshopID))
	BEGIN
		RAISERROR ('Number of reserved places is bigger than new participants limit',14,1)
		RETURN
	END
	UPDATE Workshops
		SET MaxPeople=@NewMaxPeople
		WHERE WorkshopID=@WorkshopID
END
GO

CREATE PROCEDURE ChangeConferenceDayReservation
	@ConfResID int,
	@NewNoOfParticipants int,
	@NewNoOfStudents int
AS
BEGIN
	SET NOCOUNT ON;
	IF NOT EXISTS
		(SELECT * FROM ConferenceReservations WHERE ConfResID=@ConfResID)
	BEGIN	
		RAISERROR ('No reservation with given ID',14,1)
		RETURN
	END
	IF (@NewNoOfParticipants<(SELECT COUNT(cdr.RegistrationID) FROM ConfDayRegistrations cdr 
								INNER JOIN ConferenceReservations cr ON cdr.ReservationID=cr.ConfResID WHERE cr.ConfResID=@ConfResID))
	BEGIN
		RAISERROR ('Number of registered participants is bigger than new number of reserved places',14,1)
		RETURN
	END
	IF (@NewNoOfStudents<(SELECT COUNT(cdr.RegistrationID) FROM ConfDayRegistrations cdr 
								INNER JOIN ConferenceReservations cr ON cdr.ReservationID=cr.ConfResID
								INNER JOIN Participants p ON cdr.ParticipantID=p.ParticipantID WHERE p.Student=1 AND cr.ConfResID=@ConfResID))
	BEGIN
		RAISERROR ('Number of registered students is bigger than new number of places for students',14,1)
		RETURN
	END
	UPDATE ConferenceReservations
		SET NoOfParticipants=@NewNoOfParticipants
		WHERE ConfResID=@ConfResID
	UPDATE ConferenceReservations
		SET NoOfStudents=@NewNoOfStudents
		WHERE ConfResID=@ConfResID
END		
GO

CREATE PROCEDURE CancelConfDayReservation												
	@ConfResID int
AS
BEGIN
	SET NOCOUNT ON;
	IF NOT EXISTS
		(SELECT * FROM ConferenceReservations WHERE ConfResID=@ConfResID)
	BEGIN
		RAISERROR ('No reservation with given ID',14,1)
		RETURN
	END
	UPDATE ConferenceReservations
		SET Cancelled=1
		WHERE ConfResID=@ConfResID
END	
GO
		
CREATE PROCEDURE CancelWorkshopReservation													
	@WorkResID int 
AS
BEGIN
	SET NOCOUNT ON;
	IF NOT EXISTS
		(SELECT * FROM WorkshopReservations WHERE WorkResID=@WorkResID)
	BEGIN
		RAISERROR ('No reservation with given ID',14,1)
		RETURN
	END
	UPDATE WorkshopReservations
		SET Cancelled=1
		WHERE WorkResID=@WorkResID
END
GO

CREATE PROCEDURE CancelConfDayRegistration
	@RegistrationID int
AS
BEGIN
	SET NOCOUNT ON;
	IF NOT EXISTS
		(SELECT * FROM ConfDayRegistrations WHERE RegistrationID=@RegistrationID)
	BEGIN
		RAISERROR ('No conference day registration with given ID',14,1)
		RETURN
	END
	DELETE FROM WorkshopRegistrations
		WHERE RegistrationID IN (SELECT wreg.RegistrationID FROM WorkshopRegistrations wreg 
								INNER JOIN WorkshopReservations wr ON wreg.ReservationID=wr.WorkResID
								INNER JOIN ConfDayRegistrations cdr ON wr.DayRegID=cdr.RegistrationID
								WHERE cdr.RegistrationID=@RegistrationID
								)
		
	DELETE FROM WorkshopReservations
		WHERE WorkResID IN (SELECT wr.WorkResID FROM WorkshopReservations wr
							INNER JOIN ConfDayRegistrations cdr ON wr.DayRegID=cdr.RegistrationID
							INNER JOIN ConferenceReservations cr ON cdr.RegistrationID=cr.ConfResID
							WHERE cdr.RegistrationID=@RegistrationID
							)						
		
	DELETE FROM ConfDayRegistrations
		WHERE RegistrationID=@RegistrationID
END
GO

CREATE PROCEDURE FreeUnregisteredPlaces
	@ConfResID int
AS
BEGIN
	SET NOCOUNT ON;
	IF NOT EXISTS
		(SELECT * FROM ConferenceReservations WHERE ConfResID=@ConfResID)
	BEGIN	
		RAISERROR ('No reservation with given ID',14,1)
		RETURN
	END
	DECLARE @Participants int
	SET @Participants=(SELECT COUNT(RegistrationID) FROM ConfDayRegistrations cdr WHERE cdr.ReservationID=@ConfResID)
	DECLARE @Students int
	SET @Students=(SELECT COUNT(p.ParticipantID)	FROM ConfDayRegistrations cdr INNER JOIN ConferenceReservations cr
							ON cdr.RegistrationID=cr.ConfResID	INNER JOIN Participants p ON cdr.ParticipantID=p.ParticipantID
							WHERE p.Student=1 AND cr.ConfResID=@ConfResID)
							
	EXEC ChangeConferenceDayReservation
		@ConfResID,
		@Participants,
		@Students
END
GO

CREATE PROCEDURE CancelUnpaidReservations
AS
BEGIN
	SET NOCOUNT ON;
	UPDATE ConferenceReservations
		SET Cancelled=1
		WHERE ConfResID IN (SELECT cr.ConfResID FROM Prices p INNER JOIN ConferenceDays cd ON p.DayID=cd.DayID
						INNER JOIN ConferenceReservations cr ON cd.DayID=cr.DayID 
						LEFT OUTER JOIN Payments pay ON cr.ConfResID=pay.ConfResID 
						WHERE (pay.PaymentID IS NULL 
						OR pay.Paid<((cr.NoOfParticipants-cr.NoOfStudents)*(p.Price*(1-p.Discount))+cr.NoOfStudents*(p.Price*(1-p.Discount-p.StudentDiscount))))
						AND DATEDIFF(day,cr.ResDate,GETDATE())>7
						)
END
GO

CREATE PROCEDURE EditConference						
	@ConferenceID int,
	@ConferenceName nvarchar(60),
	@Address nvarchar (50),
	@City nvarchar(40),
	@PostalCode nvarchar(10),
	@MaxPeople int
AS
BEGIN
	SET NOCOUNT ON;
	IF @ConferenceID IS NULL
	BEGIN
		RAISERROR ('ConferenceID is NULL. Can''t find conference',14,1)
		RETURN
	END
	IF @ConferenceName IS NOT NULL
	BEGIN
		UPDATE Conferences
		SET ConferenceName=@ConferenceName
		WHERE ConferenceID=@ConferenceID
	END	
	IF @Address IS NOT NULL
	BEGIN
		UPDATE Conferences
		SET Address=@Address
		WHERE ConferenceID=@ConferenceID
	END	
	IF @City IS NOT NULL
	BEGIN
		UPDATE Conferences
		SET City=@City
		WHERE ConferenceID=@ConferenceID
	END	
	IF @PostalCode IS NOT NULL
	BEGIN
		UPDATE Conferences
		SET PostalCode=@PostalCode
		WHERE ConferenceID=@ConferenceID
	END	
	IF @MaxPeople IS NOT NULL
	BEGIN
		UPDATE ConferenceDays
		SET MaxPeople=@MaxPeople
		WHERE DayID IN (SELECT cd.DayID FROM ConferenceDays cd INNER JOIN Conferences c ON cd.ConferenceID=c.ConferenceID
						WHERE c.ConferenceID=@ConferenceID)
	END
END
GO
		
CREATE PROCEDURE EditClient
	@ClientID int,
	@Company bit,
	@CompanyName nvarchar(40),
	@LastName nvarchar(25),
	@FirstName nvarchar(25),
	@Address nvarchar(50),
	@City nvarchar(40),
	@PostalCode nvarchar(10),
	@Phone nvarchar(15)
AS
BEGIN
	SET NOCOUNT ON;
	IF @ClientID IS NULL
	BEGIN
		RAISERROR ('Client ID is NULL. Can''t find client',14,1)
		RETURN
	END
	IF @Company IS NOT NULL
	BEGIN
		UPDATE Clients
		SET Company=@Company
		WHERE ClientID=@ClientID
	END	
	IF @CompanyName IS NOT NULL
	BEGIN
		UPDATE Clients
		SET CompanyName=@CompanyName
		WHERE ClientID=@ClientID AND Company=1
	END	
	IF @LastName IS NOT NULL
	BEGIN
		UPDATE Clients
		SET LastName=@LastName
		WHERE ClientID=@ClientID
	END	
	IF @FirstName IS NOT NULL
	BEGIN
		UPDATE Clients
		SET FirstName=@FirstName
		WHERE ClientID=@ClientID
	END	
	IF @Address IS NOT NULL
	BEGIN
		UPDATE Clients
		SET Address=@Address
		WHERE ClientID=@ClientID
	END	
	IF @City IS NOT NULL
	BEGIN
		UPDATE Clients
		SET City=@City
		WHERE ClientID=@ClientID
	END	
	IF @PostalCode IS NOT NULL
	BEGIN
		UPDATE Clients
		SET PostalCode=@PostalCode
		WHERE ClientID=@ClientID
	END	
	IF @Phone IS NOT NULL
	BEGIN
		UPDATE Clients
		SET Phone=@Phone
		WHERE ClientID=@ClientID
	END	
END
GO

CREATE PROCEDURE EditParticipant
	@ParticipantID int,
	@LastName nvarchar(25),
	@Firstname nvarchar(25),
	@Phone nvarchar(15),
	@Student bit,
	@StudentIDNo integer
AS
BEGIN
	SET NOCOUNT ON;
	IF @ParticipantID IS NULL
	BEGIN
		RAISERROR ('Participant ID is NULL. Can''t find client',14,1)
		RETURN
	END
	IF @LastName IS NOT NULL
	BEGIN
		UPDATE Participants
		SET LastName=@LastName
		WHERE ParticipantID=@ParticipantID
	END	
	IF @FirstName IS NOT NULL
	BEGIN
		UPDATE Participants
		SET LastName=@LastName
		WHERE ParticipantID=@ParticipantID
	END	
	IF @Phone IS NOT NULL
	BEGIN
		UPDATE Participants
		SET Phone=@Phone
		WHERE ParticipantID=@ParticipantID
	END	
	IF @Student IS NOT NULL
	BEGIN
		UPDATE Participants
		SET Student=@Student
		WHERE ParticipantID=@ParticipantID
	END	
	IF @StudentIDNo IS NOT NULL
	BEGIN
		UPDATE Participants
		SET StudentIDNo=@StudentIDNo
		WHERE ParticipantID=@ParticipantID AND Student=1
	END	
END
GO

CREATE FUNCTION ConfDayAvailablePlaces(
	@DayID int
	)
	RETURNS int
AS
BEGIN
	DECLARE @Result int
	SET @Result=(SELECT MaxPeople FROM ConferenceDays WHERE DayID=@DayID)-
				(SELECT SUM(NoOfParticipants) FROM ConferenceReservations WHERE DayID=@DayID AND Cancelled=0)
	RETURN @Result
END
GO

CREATE FUNCTION WorkshopAvailablePlaces(
	@WorkshopID int
	)
	RETURNS int
AS
BEGIN
	DECLARE @Result int
	SET @Result=(SELECT MaxPeople FROM Workshops WHERE WorkshopID=@WorkshopID)-
				(SELECT COUNT(*) FROM WorkshopReservations WHERE WorkshopID=@WorkshopID AND Cancelled=0)
	RETURN @Result
END
GO

CREATE FUNCTION CalculatePayment(
	@ReservationID int,
	@Conference int
	)
	RETURNS numeric(4,2)
AS
BEGIN
	DECLARE @Result numeric(4,2)
	IF @Conference=1
	BEGIN
		SET @Result=(SELECT((cr.NoOfParticipants-cr.NoOfStudents)*(p.Price*(1-p.Discount))+cr.NoOfStudents*(p.Price*(1-p.Discount-p.StudentDiscount)))
						FROM ConferenceReservations cr INNER JOIN ConferenceDays cd ON cr.DayID=cd.DayID AND cr.ConfResID=@ReservationID
						INNER JOIN Prices p ON p.DayID=cd.DayID WHERE cr.ConfResID=@ReservationID
						AND p.DaysTo=(SELECT TOP 1 pr.DaysTo FROM Prices pr WHERE pr.DayID=p.DayID AND DATEDIFF(day,cr.ResDate,cd.Date)>=pr.DaysTo ORDER BY pr.DaysTo)
					)
	END
	IF @Conference=0
	BEGIN
		IF EXISTS
			(SELECT * FROM WorkshopReservations wr INNER JOIN Workshops w ON wr.WorkshopID=w.WorkshopID
				INNER JOIN Prices p ON w.PriceID=p.PriceID WHERE wr.WorkResID=@ReservationID)
		BEGIN
			IF ((SELECT p.Student FROM Participants p INNER JOIN ConfDayRegistrations cdr ON p.ParticipantID=cdr.ParticipantID
				INNER JOIN WorkshopReservations wr ON cdr.RegistrationID=wr.DayRegID WHERE wr.WorkResID=@ReservationID)=1)
			BEGIN
				SET @Result=(SELECT p.Price*(1-p.Discount-p.StudentDiscount) FROM Prices p INNER JOIN Workshops w 
								ON p.PriceID=w.PriceID INNER JOIN WorkshopReservations wr ON w.WorkshopID=wr.WorkshopID)
			END
			ELSE
			BEGIN
				SET @Result=(SELECT p.Price*(1-p.Discount) FROM Prices p INNER JOIN Workshops w 
								ON p.PriceID=w.PriceID INNER JOIN WorkshopReservations wr ON w.WorkshopID=wr.WorkshopID)
			END
		END
	END
	RETURN @Result
END
GO
	
CREATE TRIGGER ClearTablesAfterCancellingConfRes
ON ConferenceReservations
AFTER UPDATE
AS
BEGIN
	DELETE FROM WorkshopRegistrations
		WHERE RegistrationID IN (SELECT wreg.RegistrationID FROM WorkshopRegistrations wreg 
								INNER JOIN WorkshopReservations wr ON wreg.ReservationID=wr.WorkResID
								INNER JOIN ConfDayRegistrations cdr ON wr.DayRegID=cdr.RegistrationID
								INNER JOIN ConferenceReservations cr ON cdr.RegistrationID=cr.ConfResID
								WHERE cr.Cancelled=1
								)
		
	DELETE FROM WorkshopReservations
		WHERE WorkResID IN (SELECT wr.WorkResID FROM WorkshopReservations wr
							INNER JOIN ConfDayRegistrations cdr ON wr.DayRegID=cdr.RegistrationID
							INNER JOIN ConferenceReservations cr ON cdr.RegistrationID=cr.ConfResID
							WHERE cr.Cancelled=1
							)				
	
	DELETE FROM ConfDayRegistrations
		WHERE RegistrationID IN (SELECT cdr.RegistrationID FROM ConfDayRegistrations cdr
								INNER JOIN ConferenceReservations cr ON cdr.RegistrationID=cr.ConfResID
								WHERE cr.Cancelled=1
								)						
END
GO

CREATE TRIGGER DeleteRegistrationAfterCancellingWorkRes
ON WorkshopReservations
AFTER UPDATE
AS
BEGIN
	DELETE FROM WorkshopRegistrations
		WHERE RegistrationID IN (SELECT wreg.RegistrationID FROM WorkshopRegistrations wreg 
								INNER JOIN WorkshopReservations wr ON wreg.ReservationID=wr.WorkResID
								WHERE wr.Cancelled=1
								)
END	
GO

CREATE TRIGGER CheckWorkshopReservations
ON WorkshopReservations
AFTER INSERT
AS
BEGIN
	IF EXISTS
		(SELECT * FROM Inserted iwr INNER JOIN Workshops iw ON iwr.WorkshopID=iw.WorkshopID
			INNER JOIN ConfDayRegistrations icdr ON iwr.DayRegID=icdr.RegistrationID
			INNER JOIN Participants ip ON icdr.ParticipantID=ip.ParticipantID
			WHERE iwr.WorkResID IN 
			(SELECT wr.WorkResID FROM WorkshopReservations wr INNER JOIN Workshops w ON wr.WorkshopID=w.WorkshopID
				INNER JOIN ConfDayRegistrations cdr ON iwr.DayRegID=cdr.RegistrationID
				INNER JOIN Participants p ON cdr.ParticipantID=p.ParticipantID
				WHERE w.WorkshopID<>iw.WorkshopID AND ip.ParticipantID=p.ParticipantID 
				AND ((iw.StartTime BETWEEN w.StartTime AND w.EndTime) OR (iw.StartTime BETWEEN w.StartTime AND w.EndTime))
			)
		)
	BEGIN 
		RAISERROR ('Can''t make a reservation for two workshops in the same time',14,1)
		ROLLBACK TRANSACTION
	END
	IF EXISTS
		(SELECT COUNT(wr.WorkResID) FROM WorkshopReservations wr INNER JOIN ConfDayRegistrations cdr ON wr.DayRegID=cdr.RegistrationID
			INNER JOIN Participants p ON cdr.ParticipantID=p.ParticipantID
			GROUP BY wr.WorkshopID, p.ParticipantID
			HAVING COUNT(wr.WorkResID)>1
		)
	BEGIN
		RAISERROR ('Can''t make two reservations for the same workshop',14,1)
		ROLLBACK TRANSACTION
	END
END
GO

CREATE TRIGGER CheckConfDayRegistrations
ON ConfDayRegistrations
AFTER INSERT
AS
BEGIN
	IF EXISTS 
		(SELECT * FROM Inserted icdr INNER JOIN ConferenceReservations icr ON icdr.ReservationID=icr.ConfResID
			INNER JOIN ConferenceDays icd ON icr.DayID=icd.DayID
			INNER JOIN Participants ip ON icdr.ParticipantID=ip.ParticipantID
			WHERE icdr.RegistrationID IN
			(SELECT cdr.RegistrationID FROM ConfDayRegistrations cdr INNER JOIN ConferenceReservations cr ON cdr.ReservationID=cr.ConfResID
				INNER JOIN ConferenceDays cd ON cr.DayID=cd.DayID
				INNER JOIN Participants p ON cdr.ParticipantID=p.ParticipantID
				WHERE cr.ConfResID<>icr.ConfResID AND ip.ParticipantID=p.ParticipantID AND icd.Date=cd.Date)
		)
	BEGIN
		RAISERROR ('Can''t register to two conferences on the same day',14,1)
		ROLLBACK TRANSACTION
	END
	IF EXISTS
		(SELECT COUNT(*) FROM Participants p INNER JOIN ConfDayRegistrations cdr ON cdr.ParticipantID=p.ParticipantID
			GROUP BY cdr.ReservationID,p.ParticipantID
			HAVING COUNT (p.ParticipantID)>1
		)
	BEGIN
		RAISERROR ('Can''t register twice on the same Reservation ID',14,1)
		ROLLBACK TRANSACTION
	END
END
GO

CREATE TRIGGER CheckConfDayMaxPeople
ON ConferenceReservations
AFTER INSERT
AS
BEGIN 
	IF EXISTS
		(SELECT SUM(cr.NoOfParticipants) FROM ConferenceReservations cr INNER JOIN ConferenceDays cd
			ON cr.DayID=cd.DayID 
			WHERE cr.Cancelled=0
			GROUP BY cd.DayID
			HAVING SUM(cr.NoOfParticipants)>(SELECT cd2.MaxPeople FROM ConferenceDays cd2 WHERE cd2.DayID=cd.DayID)
		)	
	BEGIN 
		RAISERROR ('Not enough places on this day',14,1)
		ROLLBACK TRANSACTION
	END
END
GO

CREATE TRIGGER CheckWorkshopMaxPeople
ON WorkshopReservations
AFTER INSERT
AS
BEGIN
	IF EXISTS
		(SELECT COUNT(WorkResID) FROM WorkshopReservations wr INNER JOIN Workshops w 
			ON wr.WorkshopID=w.WorkshopID
			WHERE wr.Cancelled=0
			GROUP BY w.WorkshopID
			HAVING COUNT(WorkResID)>(SELECT w2.MaxPeople FROM Workshops w2 WHERE w.WorkshopID=w2.WorkshopID)
		)
	BEGIN 
		RAISERROR ('Not enough places on this workshop',14,1)
		ROLLBACK TRANSACTION
	END
END	
GO

CREATE TRIGGER CheckWorkshopPriceNotDayPrice
ON Workshops
AFTER INSERT,UPDATE
AS
BEGIN
	IF EXISTS (SELECT w.WorkshopID FROM Workshops w INNER JOIN Prices p
							ON w.PriceID=p.PriceID AND p.DayID IS NOT NULL)
	BEGIN
		RAISERROR ('Workshop price must have ID different than day price',14,1)
		ROLLBACK TRANSACTION
	END
END
GO

CREATE TRIGGER CheckNoOfRegisteredParticipants
ON ConfDayRegistrations
AFTER INSERT
AS
BEGIN
	IF EXISTS(SELECT * FROM Inserted icdr INNER JOIN ConferenceReservations icr ON icdr.RegistrationID=icr.ConfResID
				WHERE icr.ConfResID IN (SELECT cr.ConfResID FROM ConfDayRegistrations cdr 
							INNER JOIN ConferenceReservations cr ON cdr.ReservationID=cr.ConfResID
							WHERE (SELECT COUNT (cdr2.RegistrationID) FROM ConfDayRegistrations cdr2 WHERE cdr2.ReservationID=cr.ConfResID)>cr.NoOfParticipants)
			)
	BEGIN
		RAISERROR ('No more places available for this reservation',14,1)
		ROLLBACK TRANSACTION
	END
END
GO

CREATE NONCLUSTERED INDEX ConferenceDaysConferenceID ON ConferenceDays
(
ConferenceID ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF,
ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON)

CREATE NONCLUSTERED INDEX ConferenceReservationsDayID ON ConferenceReservations
(
DayID ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF,
ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON)

CREATE NONCLUSTERED INDEX ConferenceReservationsClientID ON ConferenceReservations
(
ClientID ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF,
ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON)

CREATE NONCLUSTERED INDEX ParticipantsClientID ON Participants
(
ClientID ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF,
ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON)

CREATE NONCLUSTERED INDEX ConfDayRegistrationsReservationID ON ConfDayRegistrations
(
ReservationID ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF,
ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON)

CREATE NONCLUSTERED INDEX ConfDayRegistrationsParticipantID ON ConfDayRegistrations
(
ParticipantID ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF,
ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON)

CREATE NONCLUSTERED INDEX WorkshopReservationsWorkshopID ON WorkshopReservations
(
WorkshopID ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF,
ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON)

CREATE NONCLUSTERED INDEX WorkshopReservationsDayRegID ON WorkshopReservations
(
DayRegID ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF,
ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON)

CREATE NONCLUSTERED INDEX WorkshopsDayID ON Workshops
(
DayID ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF,
ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON)

CREATE NONCLUSTERED INDEX WorkshopsPriceID ON Workshops
(
PriceID ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF,
ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON)

CREATE NONCLUSTERED INDEX PricesDayID ON Prices
(
DayID ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF,
ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON)

CREATE NONCLUSTERED INDEX WorkshopRegistrationReservationID ON WorkshopRegistrations
(
ReservationID ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF,
ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON)

CREATE NONCLUSTERED INDEX PaymentsWorkResID ON Payments
(
WorkResID ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF,
ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON)

CREATE NONCLUSTERED INDEX PaymentsConfResID ON Payments
(
ConfResID ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF,
ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON)

CREATE NONCLUSTERED INDEX PaymentsClientID ON Payments
(
ClientID ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF,
ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON)