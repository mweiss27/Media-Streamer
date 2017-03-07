import socketio
import eventlet
import sqlite3
import datetime
import sys
import time
from flask import Flask, render_template, request, jsonify

sio = socketio.Server()
app = Flask(__name__)
conn = sqlite3.connect("DATABASE.sqlite")
print("Database connected")
sid2user = dict()
room2queue = dict()
rooms = dict()

argc = len(sys.argv)
address = 'localhost'
port = 80
if argc >= 3:
	address = sys.argv[1]
	port = int(sys.argv[2])

class Room:

	def __init__(self, id):
		self.id = id
		self.count = 0

class User:
	
	def __init__(self, room, sid, nickname):
		self.room = room
		self.sid = sid
		self.nickname = nickname
		

class Queue:

	def __init__(self, room):
		self.queue = []
		self.room = room
		self.playing = False
		
	def add(self, id):
		self.queue.append(QueueItem(id))
		sio.emit('client_add', id, room=int(self.room))
		
	def remove(self, sid, id):
		itemToPop = None
		for item in self.queue:
			if item.id == id:
				itemToPop = item
				break
		if itemToPop is not None:
			self.queue.remove(itemToPop)
			sio.emit('client_remove', [str(sid), str(id)], room=int(self.room))
	
	def play(self, sid, id, start_time):
		item = self.getQueueItem(id)
		if item is not None:
			item.start_time = start_time
			item.playback_time = 0
			self.playing = True
			sio.emit('client_play', [str(sid), str(item.id), str(start_time)], room=int(self.room))
	
	def pause(self):
		self.playing = False
		sio.emit('client_pause', room=int(self.room))
	
	def resume(self, sid, playback_time, request_time):
		if len(self.queue) > 0:
			item = self.queue[0]
			item.start_time = request_time
			item.playback_time = playback_time
			self.playing = True
			sio.emit('client_resume', [ str(sid), str(playback_time), str(request_time) ], room=int(self.room))
		else:
			print("[ERROR] Attempted to resume, but queue is empty!")

	def change_playback(self, request_time, playback_time):
		if len(self.queue) > 0:
			item = self.queue[0]
			item.start_time = request_time
			item.playback_time = playback_time
			sio.emit('client_playback', [ str(request_time), str(playback_time) ], room=int(self.room))
		else:
			print("[ERROR] Attempted to change_playback, but queue is empty!")

	def getQueueItem(self, id):
		for item in self.queue:
			if item.id == id:
				return item
		return None

class QueueItem:

	def __init__(self, id):
		self.id = id
		self.start_time = -1
		self.playback_time = -1

		
@sio.on('add_queue')
def add_queue(sid, data):
	if sid in sid2user:
		if len(data) >= 1:
			id = data[0]
			print("AddQueue -- " + str(sid) + " -- " + str(id))
			room = sid2user[sid].room
			room2queue[room].add(id)
	
@sio.on('remove_queue')
def remove_queue(sid, data):
	if sid in sid2user:
		if len(data) >= 1:
			id = data[0]
			print("RemoveQueue -- " + str(sid) + " -- " + str(id))
			room = sid2user[sid].room
			room2queue[room].remove(sid, id)
	
@sio.on('play')
def play(sid, data):
	if sid in sid2user:
		print(str(sid) + " -- PLAY")
		if len(data) >= 1:
			id = data[0]
			time = data[1]
			room = sid2user[sid].room
			room2queue[room].play(sid, id, time)
			print("play")

@sio.on('pause')
def pause(sid, data):
	if sid in sid2user:
		print(str(sid) + " -- PAUSE")
		room = sid2user[sid].room
		room2queue[room].pause()

@sio.on('resume')
def resume(sid, data):
	if sid in sid2user:
		print(str(sid) + " -- RESUME")
		if len(data) >= 2:
			playback_time = data[0]
			resume_time = data[1]
			room = sid2user[sid].room
			room2queue[room].resume(sid, playback_time, resume_time)
	
	
@sio.on('change playback')
def change_playback(sid, data):
	print("change 	playback -- " + str(data))
	if sid in sid2user:
		if len(data) >= 2:
			request_time = data[0]
			time = data[1]
			room = sid2user[sid].room
			room2queue[room].change_playback(request_time, time)
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

		if roomNum not in rooms:
			rooms[int(roomNum)] = Room(int(roomNum))
		rooms[roomNum].count += 1
	
@app.route('/get_users', methods=['GET'])
def getUsers():
	roomNum = request.args.get('roomNum', None, type=int)
	if roomNum is None:
		return "roomNum not provided"

	print("getUsers: " + str(roomNum))
	result = []
	for sid, user in sid2user.items():
		if user.room == roomNum:
			result.append([user.sid, user.nickname])
	return jsonify(users=result)

@app.route('/get_queue', methods=['GET'])
def getQueue():
	roomNum = request.args.get('roomNum', None, type=int)
	if roomNum is None:
		return "roomNum not provided"
	print("queue len: " + str(len(room2queue)))

	for key in room2queue:
		print("Key: " + str(type(key)) + ", " + str(int(key) == int(roomNum)))
	result = []
	if roomNum in room2queue:
		queue = room2queue[roomNum]
		print("queue: " + str(queue))
		print("queue.queue: " + str(queue.queue))

		for item in queue.queue:
			result.append([str(queue.playing and item.start_time > 0), str(item.id), str(item.start_time), str(item.playback_time)])
		#result.append([ str(True),  "spotify:track:0NmeI6UpRE27dxxgosD5n9", str(int(round((time.time()-5) * 1000))), str(0)])
		#result.append([ str(False),  "spotify:track:0FE9t6xYkqWXU2ahLh6D8X", str(-1), str(-1)])
		return jsonify(queue=result)
	else:
		print("room2queue: " + str(room2queue))
		return "Invalid room"

@app.route('/get_rooms', methods=['GET'])
def getRooms():
	result = {}
	for roomNum in rooms:
		room = rooms[roomNum]
		result[int(roomNum)] = room.count

	return jsonify(rooms=result)

@sio.on('request sid')
def requestSid(sid, data):
	sio.emit('sid_response', str(sid), room=sid)

@sio.on('leave room')
def leave_room(sid, data):
	print("LEAVE ROOM -- " + str(sid))
	leave(sid)
	

@sio.on('disconnect')
def disconnect(sid):
	print("Disconnect -- " + str(sid))
	leave(sid)

def leave(sid):
	if sid in sid2user:

		user = sid2user[sid]
		name = user.nickname
		roomNum = user.room

		if roomNum in rooms:
			room = rooms[roomNum]
			room.count -= 1
			if room.count < 0:
				room.count = 0
			print("Room count for " + str(roomNum) + ": " + str(room.count))
			if room.count == 0:
				print("Cleaning up room " + str(roomNum))
				if roomNum in room2queue:
					print("Clearing queue")
					room2queue[roomNum].queue = []

				rooms.pop(roomNum)

		sio.leave_room(sid, int(roomNum))
		sio.emit("remove user", str(sid), room=int(roomNum))
		sid2user.pop(sid)

		print("{0} is leaving room: {1}".format(name, roomNum))

if __name__ == '__main__':
    # wrap Flask application with socketio's middleware
    app = socketio.Middleware(sio, app)

    # deploy as an eventlet WSGI server
    eventlet.wsgi.server(eventlet.listen((address, port)), app)
