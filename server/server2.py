import socketio
import eventlet
import sqlite3
import datetime
import sys
from flask import Flask, render_template, request, jsonify

sio = socketio.Server()
app = Flask(__name__)
conn = sqlite3.connect("DATABASE.sqlite")
print("Database connected")
sid2user = dict()
room2queue = dict()

argc = len(sys.argv)
address = 'localhost'
port = 80
if argc >= 3:
	address = sys.argv[1]
	port = int(sys.argv[2])

class User:
	
	def __init__(self, room, sid, nickname):
		self.room = room
		self.sid = sid
		self.nickname = nickname
		

class Queue:

	def __init__(self, room):
		self.queue = []
		self.room = room
		
	def add(self, id):
		self.queue.append(QueueItem(id))
		sio.emit('client_add', id, room=int(self.room))
		
	def remove(self, id):
		first_or_default = next((x for x in lst if x.id == id), None)
		if first_or_default is not None:
			queue.pop(first_or_default)
			sio.emit('client_remove', id, room=int(self.room))
	
	def play(self, sid, start_time):
		sio.emit('client_play', [str(sid), str(self.queue[0].id), str(start_time)], room=int(self.room))
	
	def pause(self):
		sio.emit('client_pause', room=int(self.room))
	
	def resume(self, sid, playback_time, resume_time):
		sio.emit('client_resume', [ str(sid), str(playback_time), str(resume_time) ], room=int(self.room))

	def change_playback(self, playback):
		print("change_playback")
		#sio.emit('client_playback', {"id": self.queue[0].id, "time": self.queue[0].playback_time}, room=int(self.room))


class QueueItem:

	def __init__(self, id):
		self.id = id
		self.playback_time = 0
		
	def pause(self, playback_time):
		self.playback_time = playback_time


@sio.on('add_queue')
def add_queue(sid, data):
	if len(data) >= 1:
		id = data[0]
		print("AddQueue -- " + str(sid) + " -- " + str(id))
		room = sid2user[sid].room
		room2queue[room].add(id)
	
@sio.on('remove_queue')
def remove_queue(sid, data):
	if len(data) >= 1:
		id = data[0]
		print("RemoveQueue -- " + str(sid) + " -- " + str(id))
		room = sid2user[sid].room
		room2queue[room].remove(id)
	
@sio.on('play')
def play(sid, data):
	print(str(sid) + " -- PLAY")
	if len(data) >= 1:
		time = data[0]
		room = sid2user[sid].room
		room2queue[room].play(sid, time)
		print("play")

@sio.on('pause')
def pause(sid, data):
	print(str(sid) + " -- PAUSE")
	room = sid2user[sid].room
	room2queue[room].pause()

@sio.on('resume')
def resume(sid, data):
	print(str(sid) + " -- RESUME")
	if len(data) >= 2:
		playback_time = data[0]
		resume_time = data[1]
		room = sid2user[sid].room
		room2queue[room].resume(sid, playback_time, resume_time)
	
	
@sio.on('change_playback')
def change_playback(sid, data):
	if len(data) >= 1:
		time = data[0]
		room = sid2user[sid].room
		room2queue[room].change_playback(time)
		print("change playback")

@sio.on('connect')
def connect(sid, environ):
	print('connect ', sid)

@sio.on('my message')
def message(sid, data):
    print('message ', data)
    
@sio.on('join room')
def join(sid, data):
	if len(data) >= 1:
		roomNum = data[0]
		print(sid, roomNum)
		print("Attempted Join")
		cursor = conn.execute("SELECT DisplayName FROM Room WHERE RoomNum=?", (roomNum,))
		found = False
		for row in cursor:
			print("Valid room number: " + str(row))
			found = True
			roomName = row[0]
			sio.emit("join reply", roomName, room=sid)
		if not found:
			print("invalid room number")
			sio.emit("join reply", "nil", room=sid)

@sio.on('create room')
def createRoom(sid, data):
	if len(data) >= 2:
		displayName = data[0]
		roomNum = data[1]
		conn.execute("INSERT INTO Room (RoomNum, DisplayName) VALUES (?, ?)", (roomNum, displayName))
		conn.commit()
		sio.emit("create reply", "1", room=sid)
		print("Room Created")
	
@sio.on('enter room')
def enterRoom(sid, data):
	if len(data) >= 2:
		roomNum = data[0]
		nickname = data[1]
		print("enterRoom", sid, roomNum, nickname)

		#Create a User from the Socket ID
		sid2user[sid] = User(roomNum, sid, nickname)

		print("Adding " + str(sid) + " to " + str(roomNum))
		#Add this Socket ID to a Room containing all the users in this media room
		sio.enter_room(sid, int(roomNum))

		#Respond with a unique ID of the user joining, and a nickname.
		sio.emit("add user", [sid, nickname], room=int(roomNum))

		print(nickname + " entered room " + str(roomNum))
		if roomNum not in room2queue:
			room2queue[roomNum] = Queue(roomNum)
	
@app.route('/get_users', methods=['GET'])
def getUsers():
	roomNum = request.args.get('roomNum', None, type=int)
	print("getUsers: " + str(roomNum))
	result = []
	for sid, user in sid2user.items():
		if user.room == roomNum:
			result.append([user.sid, user.nickname])
	return jsonify(users=result)

@sio.on('request sid')
def requestSid(sid, data):
	sio.emit('sid_response', str(sid), room=sid)

@sio.on('leave room')
def leave_room(sid, data):
	if len(data) >= 1:
		roomNum = data[0]
		print("remove user -- " + str(sid))
		sio.leave_room(sid, int(roomNum))
		nickname = sid2user[sid].nickname
		sio.emit("remove user", str(sid), room=int(roomNum))
		sid2user.pop(sid)
		
		print("{0} is leaving room: {1}".format(nickname, roomNum))

@sio.on('disconnect')
def disconnect(sid):
	if sid in sid2user:
		print("remove user -- " + str(sid))
		roomNum = sid2user[sid].room
		sio.leave_room(sid, int(roomNum))
		sio.emit("remove user", str(sid), room=int(roomNum))
		sid2user.pop(sid)
	print('disconnect ', sid)


if __name__ == '__main__':
    # wrap Flask application with socketio's middleware
    app = socketio.Middleware(sio, app)

    # deploy as an eventlet WSGI server
    eventlet.wsgi.server(eventlet.listen((address, port)), app)
