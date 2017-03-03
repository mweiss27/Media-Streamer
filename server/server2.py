import socketio
import eventlet
import sqlite3
from flask import Flask, render_template

class User:
	
	def __init__(self, room, nickname):
		self.room = room
		self.nickname = nickname

sio = socketio.Server()
app = Flask(__name__)
conn = sqlite3.connect("DATABASE.sqlite")
print("Database connected")
sid2user = dict()

@sio.on('connect')
def connect(sid, environ):
    print('connect ', sid)

@sio.on('my message')
def message(sid, data):
    print('message ', data)

@sio.on('disconnect')
def disconnect(sid):
    if sid in sid2user:
    	roomNum = sid2user[sid].room
    	sio.emit("remove user", sid2user[sid].nickname, room=roomNum)
    	sid2user.pop(sid)
    print('disconnect ', sid)
    
@sio.on('join room')
def join(sid, roomNum):
	print(roomNum)
	print("Attempted Join")
	cursor = conn.execute("SELECT DisplayName FROM Room WHERE RoomNum=?", (roomNum,))
	found = False
	for row in cursor:
		print("Valid room number")
		found = True
		roomNum = row[0]
		sio.emit("join reply", roomNum, room=sid)
	if not found:
		print("invalid room number")
		roomNum = "nil"
		sio.emit("join reply", roomNum, room=sid)

@sio.on('create room')
def createRoom(sid, displayName, roomNum):
	conn.execute("INSERT INTO Room (RoomNum, DisplayName) VALUES (?, ?)", (roomNum, displayName))
	conn.commit()
	print("Room Created")
	
@sio.on('enter room')
def enterRoom(sid, roomNum, nickname):
	sid2user[sid] = User(roomNum, nickname)
	sio.enter_room(sid, roomNum)
	for sid, user in sid2user.items():
		if user.room == roomNum:
			sio.emit("add user", sid2user[sid].nickname, room=roomNum)
	sio.emit("add user", nickname, room=roomNum)
	print(nickname + " entered room " + roomNum)
	
@sio.on('leave room')
def leave_room(sid, roomNum):
    sio.leave_room(sid, roomNum)
    nickname = sid2user[sid].nickname
    sio.emit("remove user", nickname, room=roomNum)
    sid2user.pop(sid)
    
    print("{0} is leaving room: {1}".format(nickname, roomNum))

if __name__ == '__main__':
    # wrap Flask application with socketio's middleware
    app = socketio.Middleware(sio, app)

    # deploy as an eventlet WSGI server
    eventlet.wsgi.server(eventlet.listen(('192.168.1.117', 80)), app)
