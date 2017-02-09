#!/bin/python

from twisted.internet.protocol import Factory, Protocol
from twisted.internet import reactor
from twisted.enterprise import adbapi
 
databaseFile = "DATABASE.sqlite"
dbpool = adbapi.ConnectionPool("sqlite3", databaseFile, check_same_thread=False)

class MediaStreamer(Protocol):
    
    names = dict()
    roomMapping = dict()
    
    def connectionMade(self):
        self.factory.clients.append(self)
        print ("clients are ", self.factory.clients)
 
    def connectionLost(self, reason):
        self.factory.clients.remove(self)
        
    def dataReceived(self, data):
        a = data.decode().split(':')
        print (a)
        if len(a) > 1:
            command = a[0]
            content = a[1]
            
            if command == "login":
            	self.loginUser(content)
            
            #print(content)
 
            #msg = ""
            #if command == "iam":
            #    self.name = content
            #    msg = self.name + " has joined"
 
            #elif command == "msg":
            #    msg = self.name + ": " + content
            #    print (msg)
 
            #for c in self.factory.clients:
            #    c.message(msg)
    
    def loginUser(self, message):
    	a = message.split(',')
    	if len(a) == 2:
    		print("valid request")
    		uuid = a[0]
    		displayName = a[1]
    		print(uuid)
    		print(displayName)
    		self.name = uuid
    		self.names[uuid] = displayName
    		
    		def selectResult(data):
    			if data[0][0] != 1:
    				print("User Not Registered")
    				i = dbpool.runQuery("INSERT INTO UserInfo (UUID,DisplayName) VALUES (?,?)", (uuid, displayName,))
    				i.addCallback(insertResult)
    			else:
    				print("User already registered")
    			
    		def insertResult(data):
    			print('user registered')
    			
    		q = dbpool.runQuery("SELECT COUNT(DisplayName) FROM UserInfo WHERE UUID=?", (uuid,))
    		q.addCallback(selectResult)
    	else:
    		print('Invalid Registration')
    		
                
    def message(self, message):
        self.transport.write((message + '\n').encode('utf-8'))
 
factory = Factory()
factory.protocol = MediaStreamer
factory.clients = []
factory.users = [] 
reactor.listenTCP(80, factory)
print ("Media Streamer Server has started")
reactor.run()
