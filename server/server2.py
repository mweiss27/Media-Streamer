import socketio
import eventlet
import sqlite3
from flask import Flask, render_template

sio = socketio.Server()
app = Flask(__name__)
conn = sqlite3.connect("DATABASE.sqlite")
print("Database connected")

@sio.on('connect')
def connect(sid, environ):
    print('connect ', sid)

@sio.on('my message')
def message(sid, data):
    print('message ', data)

@sio.on('disconnect')
def disconnect(sid):
    print('disconnect ', sid)
    
@sio.on('join room')
def join(sid, roomNum):
	print(roomNum)
	print("Attempted Join")
	cursor = conn.execute("SELECT DisplayName FROM Room WHERE RoomNum=?", (roomNum,))
	for row in cursor:
		if row[0] is not None:
			roomNum = row[0]
			sio.emit("join reply", roomNum, room=sid)
	
@sio.on('create room')
def createRoom(sid, displayName, roomNum):
	conn.execute("INSERT INTO Room (RoomNum, DisplayName) VALUES (?, ?)", (roomNum, displayName))
	conn.commit()
	print("Room Created")

if __name__ == '__main__':
    # wrap Flask application with socketio's middleware
    app = socketio.Middleware(sio, app)

    # deploy as an eventlet WSGI server
    eventlet.wsgi.server(eventlet.listen(('', 80)), app)