import socketio
import eventlet
import sqlite3
import datetime
import sys
from flask import Flask, render_template

sio = socketio.Server()
app = Flask(__name__)
conn = sqlite3.connect("DATABASE.sqlite")
print("Database connected")
sid2user = dict()
room2queue = dict()

argc = len(sys.argv)
port = 80
if argc >= 2:
	port = int(sys.argv[1])

class User:
	
	def __init__(self, room, nickname):
		self.room = room
		self.nickname = nickname
		

class Queue:

	def __init__(self, room):
		self.queue = []
		self.room = room
		self.playing = False
		
	def add(self, id):
		self.queue.append(QueueItem(id))
		sio.emit('client_add', id, room=self.room)
		
	def remove(self, id):
		first_or_default = next((x for x in lst if x.id == id), None)
		if first_or_default is not None:
			queue.pop(first_or_default)
			sio.emit('client_remove', id, room=self.room)
			
	def play(self):
		self.playing = True
		sio.emit('client_play', {"id": self.queue[0].id, "time": self.queue[0].playback_time}, room=self.room)
	
	def pause(self, time):
		self.playing = False
		self.queue[0].playback_time = time
		sio.emit('client_pause', room=self.room)
	
	def change_playback(self, playback):
		self.queue[0].playback_time = playback
		sio.emit('client_playback', {"id": self.queue[0].id, "time": self.queue[0].playback_time}, room=self.room)

class QueueItem:

	def __init__(self, id):
		self.id = id
		self.playback_time = 0
		
	def pause(self, playback_time):
		self.playback_time = playback_time


@sio.on('add_queue')
def add_queue(sid, id, time):
	room = sid2user[sid].room
	room2queue[room].add(id, sid)
	print("add queue")
	
@sio.on('remove_queue')
def add_queue(sid, id):
	room = sid2user[sid].room
	room2queue[room].remove(id)
	print("remove queue")
	
@sio.on('play')
def add_queue(sid, data):
	room = sid2user[sid].room
	room2queue[room].play()
	print("play")
	
@sio.on('pause')
def add_queue(sid, time):
	room = sid2user[sid].room
	room2queue[room].pause(time)
	print("pause")
	
@sio.on('change_playback')
def add_queue(sid, time):
	room = sid2user[sid].room
	room2queue[room].change_playback(time)
	print("change playback")

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
	print(sid, roomNum)
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
	sio.emit("create reply", "1")
	print("Room Created")
	
@sio.on('enter room')
def enterRoom(sid, roomNum, nickname):
	print("enterRoom", sid, roomNum, nickname)
	sid2user[sid] = User(roomNum, nickname)
	sio.enter_room(sid, roomNum)
	for sid, user in sid2user.items():
		if user.room == roomNum:
			sio.emit("add user", sid2user[sid].nickname, room=roomNum)
	sio.emit("add user", nickname, room=roomNum)
	print(nickname + " entered room " + roomNum)
	if roomNum not in room2queue:
		room2queue[roomNum] = Queue(roomNum)
	
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
    eventlet.wsgi.server(eventlet.listen(('localhost', port)), app)
