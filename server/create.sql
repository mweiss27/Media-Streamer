CREATE TABLE UserInfo(
	UUID VARCHAR(40) NOT NULL,
	DisplayName VARCHAR(50),
	PRIMARY KEY(UUID)
);
CREATE TABLE Room(
	RoomNum INT NOT NULL,
	DisplayName VARCHAR(30),
	PRIMARY KEY(RoomNum)
);	
CREATE TABLE Queue(
	RoomNum INT NOT NULL,
	ContentID VARCHAR(70) NOT NULL,
	ServiceProvider INT NOT NULL,
	TimeAdded DATE NOT NULL,
	PRIMARY KEY(ContentID, TimeAdded),
	FOREIGN KEY(RoomNum) REFERENCES Room(RoomNum)
);
CREATE TABLE Membership(
	RoomNum INT NOT NULL,
	UUID CHAR(40),
	PRIMARY KEY(RoomNum, UUID),
	FOREIGN KEY(RoomNum) REFERENCES Room(RoomNum),
	FOREIGN KEY(UUID) REFERENCES UserInfo(UUID)
);