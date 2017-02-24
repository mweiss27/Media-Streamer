import socketio
import eventlet
import sqlite3
from flask import Flask, render_template

sio = socketio.Server()
app = Flask(__name__)
conn = sqlite3.connect("DATABASE.sqlite")
print("Database connected")
sid2nick = dict()
sid2room = dict()

@sio.on('connect')
def connect(sid, environ):
    print('connect ', sid)

@sio.on('my message')
def message(sid, data):
    print('message ', data)

@sio.on('disconnect')
def disconnect(sid):
    if sid in sid2room:
    	roomNum = sid2room[sid]
    	sio.emit("remove user", sid2nick[sid], room=roomNum)
    	sid2room.pop(sid)
    	sid2nick.pop(sid)
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
	sid2nick[sid] = nickname
	sid2room[sid] = roomNum
	sio.enter_room(sid, roomNum)
	for sid, room in sid2room.items():
		if room == roomNum:
			sio.emit("add user", sid2nick[sid], room=roomNum)
	sio.emit("add user", nickname, room=roomNum)
	print(nickname + " entered room " + roomNum)
	
@sio.on('leave room')
def leave_room(sid, roomNum):
    sio.leave_room(sid, roomNum)
    sio.emit("remove user", sid2nick[sid], room=roomNum)
    sid2room.pop(sid)
    sid2nick.pop(sid)
    
    print("someone is leaving room: " + roomNum)

if __name__ == '__main__':
    # wrap Flask application with socketio's middleware
    app = socketio.Middleware(sio, app)

    # deploy as an eventlet WSGI server
    eventlet.wsgi.server(eventlet.listen(('', 80)), app)