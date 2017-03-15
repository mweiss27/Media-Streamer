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

#{ sid = User(roomNum: int, sid: String, nickname: String) }
sid2user = dict()

# { roomNum = Queue(queue: [], roomNum: int, playing: bool) }
room2queue = dict()

# { roomNum = Room(roomNum: int) }
rooms = dict()

argc = len(sys.argv)
address = 'localhost'
port = 80
if argc >= 3:
	address = sys.argv[1]
	port = int(sys.argv[2])

currentTimeMillis = lambda: int(round(time.time() * 1000))

def loge(event, data, room):
	print("socket.emit -- " + str(event) + " -- " + str(data) + " -- " + str(room))

def logr(event):
	print("socket.recv -- " + str(event))

"""
Room.id: int
Room.count: int

User.room: int
User.sid: String
User.nickname: String


Queue.queue: [QueueItem]
Queue.room: int
Queue.playing: bool

Queue.add(id)
Queue.removeFirst() -> QueueItem
Queue.remove(id) -> QueueItem
Queue.getQueueItem(id) -> QueueItem

QueueItem.id: String
QueueItem.start_time: double
QueueItem.playback_time: double

"""

#data: [  ]
#responses: [ client_remove(id), client_stop(), client_play(id, start_time) ]
@sio.on("request_next")
def requestNext(sid, data):
	logr("request_next")
	#To go to the next song, we need to remove the current song,
	#and play the then-current song
	if sid in sid2user:
		user = sid2user[sid]
		roomNum = user.room
		if roomNum in room2queue:
			queue = room2queue[roomNum]
			if len(queue.queue) > 0:
				item = queue.queue.pop(0)
				result = [item.id]
				sio.emit("client_remove", result, room=str(roomNum))
				loge("client_remove", result, roomNum)
				#Don't return, we need to emit a play
			else:
				print("[ERROR] request_next called but there is no current song -- len(queue) == 0")

				Room = rooms[roomNum]
				Room.pause()

				sio.emit("client_stop", [], room=str(roomNum))
				loge("client_stop", [], roomNum)
				return

			if len(queue.queue) > 0:
				item = queue.queue.pop(0)

				response_time = currentTimeMillis()
				result = [item.id, str(response_time)]

				Room = rooms[roomNum]
				Room.play(0, response_time)

				sio.emit("client_play", result, room=str(roomNum))
				loge("client_play", result, roomNum)
			else:

				Room = rooms[roomNum]
				Room.pause()

				sio.emit("client_stop", [], room=str(roomNum))
				loge("client_stop", [], roomNum)

		else:
			print("[ERROR] roomNum not in room2queue: " + str(roomNum))
	else:
		print("[ERROR] sid not in sid2user: " + str(sid))

#data: [ id ]
#responses: [ client_add(id), client_play(id, time) ]
@sio.on("request_add")
def requestAdd(sid, data):
	logr("request_add")
	if sid in sid2user:
		if len(data) > 0:
			id = data[0]
			print("RequestAdd -- " + str(sid) + " -- " + str(id))
			roomNum = sid2user[sid].room
			if roomNum in room2queue:
				Queue = room2queue[roomNum]
				addRes = Queue.add(id)
				if addRes:
					result = [id]
					sio.emit("client_add", result, room=str(roomNum))
					loge("client_add", result, roomNum)

					if len(Queue.queue) == 1:
						print("This is the only song in the queue now. Sending a client_play")
						response_time = currentTimeMillis()
						result = [id, str(response_time)]
						Room = rooms[roomNum]
						Room.play(0, response_time)
						
						sio.emit("client_play", result, room=str(roomNum))
						loge("client_play", result, roomNum)

				else:
					print("[ERROR] queue.add returned False: " + str(addRes))
		else:
			print("[ERROR] len(data) is not > 0")
	else:
		print("[ERROR] sid is not in sid2user")

#data: [ id ]
#responses: [ client_remove(id) ]
@sio.on("request_remove")
def requestRremove(sid, data):
	logr("request_remove")
	if sid in sid2user:
		if len(data) > 0:
			id = data[0]
			if id is not None and len(id) > 0:
				user = sid2user[sid]
				roomNum = user.room
				if roomNum in room2queue:
					queue = room2queue[roomNum].queue
					if len(queue) > 0:
						removedItem = queue.remove(id)
						result = [removedItem.id]
						sio.emit("client_remove", result, room=str(roomNum))
						loge("client_remove", result, roomNum)
					else:

						Room = rooms[roomNum]
						Room.pause()

						sio.emit("client_stop", [], room=str(roomNum))
						loge("client_stop", [], room)
				else:
					print("[ERROR] roomNum not in room2queue")
			else:
				print("[ERROR] provided id is None")
		else:
			print("[ERROR] [data] is empty")


	else:
		print("[ERROR] sid not in sid2user: " + str(sid))


#data: [ ]
#responses: [ client_pause() ]
@sio.on("request_pause")
def requestPause(sid, data):
	logr("request_pause")
	if sid in sid2user:
		user = sid2user[sid]
		roomNum = user.room
		if roomNum in room2queue:
			queue = room2queue[roomNum]

			Room = rooms[roomNum]
			Room.pause()

			sio.emit("client_pause", [], room=str(roomNum))
			loge("client_pause", [], roomNum)
	else:
		print("[ERROR] sid not in sid2user: " + str(sid))

#data: [ resume_time ]
#responses: [ client_resume(currentSongId, resume_time, response_time) ]
@sio.on("request_resume")
def requestResume(sid, data):
	logr("request_resume")
	if sid in sid2user:
		if len(data) > 0:
			user = sid2user[sid]
			roomNum = user.room
			resume_time = data[0]

			if roomNum in room2queue:
				queue = room2queue[roomNum]
				response_time = currentTimeMillis()
				result = [str(queue.queue[0].id), str(resume_time), str(response_time)]

				Room = rooms[roomNum]
				Room.play(resume_time, response_time)

				sio.emit("client_resume", result, room=str(roomNum))
				loge("client_resume", result, roomNum)
			else:
				print("[ERROR] roomNum not in room2queue")
		else:
			print("[ERROR] len(data) is not > 0")
	else:
		print("[ERROR] sid not in sid2user: " + str(sid))

#data: [scrub_time]
#responses: [ client_scrub(scrub_time, time) ]
@sio.on("request_scrub")
def requestScrub(sid, data):
	logr("request_scrub")
	if sid in sid2user:
		user = sid2user[sid]
		roomNum = user.room
		if len(data) > 0:
			scrub_time = data[0]

			result = [str(scrub_time), str(currentTimeMillis())]
			sio.emit("client_scrub", result, room=str(roomNum))
			loge("client_scrub", result, roomNum)
		else:
			print("[ERROR] [data] is empty")
	else:
		print("[ERROR] sid not in sid2user: " + str(sid))




#data: [id]
#responses: [ client_add(id) ]
@sio.on('add_queue')
def add_queue(sid, data):
	print("[ERROR] add_queue is deprecated")
	
@sio.on('remove_queue')
def remove_queue(sid, data):
	print("[ERROR] remove_queue is deprecated")
	# if sid in sid2user:
	# 	if len(data) >= 1:
	# 		id = data[0]
	# 		print("RemoveQueue -- " + str(sid) + " -- " + str(id))
	# 		room = sid2user[sid].room
	# 		room2queue[room].remove(sid, id)
	
@sio.on('play')
def play(sid, data):
	print("[ERROR] play is deprecated")
	# if sid in sid2user:
	# 	print(str(sid) + " -- PLAY")
	# 	if len(data) >= 1:
	# 		id = data[0]
	# 		time = data[1]
	# 		room = sid2user[sid].room
	# 		room2queue[room].play(sid, id, time)
	# 		print("play")

@sio.on('pause')
def pause(sid, data):
	print("[ERROR] pause is deprecated")
	# if sid in sid2user:
	# 	print(str(sid) + " -- PAUSE")
	# 	room = sid2user[sid].room
	# 	room2queue[room].pause()

@sio.on('resume')
def resume(sid, data):
	print("[ERROR] resume is deprecated")
	# if sid in sid2user:
	# 	print(str(sid) + " -- RESUME")
	# 	if len(data) >= 2:
	# 		playback_time = data[0]
	# 		resume_time = data[1]
	# 		room = sid2user[sid].room
	# 		room2queue[room].resume(sid, playback_time, resume_time)
	
	
@sio.on('change playback')
def change_playback(sid, data):
	print("[ERROR] change playback is deprecated")
	# print("change 	playback -- " + str(data))
	# if sid in sid2user:
	# 	if len(data) >= 2:
	# 		request_time = data[0]
	# 		time = data[1]
	# 		room = sid2user[sid].room
	# 		room2queue[room].change_playback(request_time, time)
	# 		print("change playback")

@sio.on('connect')
def connect(sid, environ):
	logr("connect")
	print('connect ', sid)

@sio.on('my message')
def message(sid, data):
	logr("my message")
 	print('message ', data)
    
@sio.on('join room')
def join(sid, data):
	logr("join room")
	print("join room")
	if len(data) > 0:
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
			loge("join reply", roomName, sid)
		if not found:
			print("invalid room number")
			sio.emit("join reply", "nil", room=sid)
			loge("join reply", "nil", sid)
	else:
		print("[ERROR] len(data) is not > 0")

@sio.on('create room')
def createRoom(sid, data):
	logr("create room")
	print("create room")
	if len(data) > 1:
		displayName = data[0]
		roomNum = data[1]
		conn.execute("INSERT INTO Room (RoomNum, DisplayName) VALUES (?, ?)", (roomNum, displayName))
		conn.commit()
		sio.emit("create reply", "1", room=sid)
		loge("create reply", "1", sid)
		print("Room Created")
	else:
		print("[ERROR] len(data) is not > 1")
	
@sio.on('enter room')
def enterRoom(sid, data):
	logr("enter room")
	if len(data) >= 2:
		roomNum = data[0]
		nickname = data[1]
		print("enterRoom", sid, roomNum, nickname)

		#Create a User from the Socket ID
		sid2user[sid] = User(roomNum, sid, nickname)

		print("[enter_room] Adding " + str(sid) + " to " + str(roomNum) + " -- type(roomNum): " + str(type(roomNum)))
		#Add this Socket ID to a Room containing all the users in this media room
		sio.enter_room(sid, str(roomNum))

		#Respond with a unique ID of the user joining, and a nickname.
		sio.emit("add user", [sid, nickname], room=str(roomNum))

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

	result = []
	if roomNum in room2queue:
		Room = rooms[roomNum]
		Queue = room2queue[roomNum]

		for item in Queue.queue:
			result.append([str(Room.playing and Room.playback_time >= 0), str(item.id), str(Room.response_time), str(Room.playback_time)])
		return jsonify(queue=result)
	else:
		msg = "[ERROR] roomNum not in room2queue: " + str(roomNum) + " -- " + str(room2queue)
		print(msg)
		return msg

@app.route('/get_rooms', methods=['GET'])
def getRooms():
	result = {}
	for roomNum in rooms:
		room = rooms[roomNum]
		result[int(roomNum)] = room.count

	return jsonify(rooms=result)

@sio.on("request_display_change")
def requestDisplayChange(sid, data):
	logr("request_display_change")
	if sid in sid2user:
		if len(data) > 0:
			User = sid2user[sid]
			roomNum = User.room
			newName = data[0]

			conn.execute("UPDATE Room SET DisplayName = ? WHERE RoomNum = ?", (newName, roomNum))
			conn.commit()

			result = [ newName ]
			sio.emit("client_change_display", result, room=str(roomNum))
			loge("client_change_display", result, roomNum)

		else:
			print("[ERROR] len(data) is not > 0")
	else:
		print("[ERROR] sid not in sid2user")

@sio.on('request sid')
def requestSid(sid, data):
	logr("request sid")
	sio.emit('sid_response', sid, room=sid)
	loge("sid_response", sid, sid)

@sio.on('leave room')
def leave_room(sid, data):
	logr("leave room")
	print("LEAVE ROOM -- " + str(sid))
	leave(sid)
	

@sio.on('disconnect')
def disconnect(sid):
	logr("disconnect")
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

		sio.leave_room(sid, roomNum)
		sio.emit("remove user", str(sid), room=str(roomNum))
		sid2user.pop(sid)

		print("{0} is leaving room: {1}".format(name, roomNum))

class Room:

	def __init__(self, id):
		self.id = id
		self.playing = False
		self.playback_time = -1
		self.response_time = -1		
		self.count = 0

	def play(self, playback_time, response_time):
		self.playback_time = playback_time
		self.response_time = response_time
		self.playing = True
		print("Room.play -- " + str(playback_time) + " -- " + str(response_time))

	def pause(self):
		self.playing = False
		print("Room.pause")

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
		current = len(self.queue)
		self.queue.append(QueueItem(id))
		if len(self.queue) > current:
			return True
		return False
		
	def removeFirst(self):
		if len(self.queue) > 0:
			return self.pop(0)
		return None

	def remove(self, id):
		itemToPop = None
		for item in self.queue:
			if item.id == id:
				itemToPop = item
				break
		if itemToPop is not None:
			self.queue.remove(itemToPop)
		return itemToPop

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

if __name__ == '__main__':
	# wrap Flask application with socketio's middleware
	app = socketio.Middleware(sio, app)

	# deploy as an eventlet WSGI server
	eventlet.wsgi.server(eventlet.listen((address, port)), app)


