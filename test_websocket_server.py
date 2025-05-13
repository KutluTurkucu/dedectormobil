import asyncio
import websockets
import json
import math
import time
from datetime import datetime

# Simüle edilmiş metal dedektör durumu
detector_state = {
    "is_on": False,
    "time": 0,
    "amplitude": 0
}

async def send_data(websocket):
    while True:
        if detector_state["is_on"]:
            # Sinüs dalgası oluştur
            detector_state["time"] += 0.1
            raw_signal = math.sin(detector_state["time"]) * 2047.5 + 2047.5
            
            # Metal tespit simülasyonu (her 5 saniyede bir)
            if int(detector_state["time"]) % 5 == 0:
                metal_data = {
                    "metal_type": "Demir",
                    "confidence": 0.85 + math.sin(detector_state["time"]) * 0.1,
                    "signal_strength": 0.75 + math.sin(detector_state["time"]) * 0.2,
                    "distance": 10 + math.sin(detector_state["time"]) * 5,
                    "timestamp": datetime.utcnow().isoformat() + "Z",
                    "raw_signal": raw_signal,
                    "sensor_data": {
                        "inductance": 234.5 + math.sin(detector_state["time"]) * 10,
                        "resistance": 12.3 + math.sin(detector_state["time"]) * 2,
                        "phase": 45.6 + math.sin(detector_state["time"]) * 5
                    }
                }
                await websocket.send(json.dumps(metal_data))
            else:
                # Sadece raw sinyal gönder
                await websocket.send(json.dumps({"raw_signal": raw_signal}))
        
        await asyncio.sleep(0.1)

async def handle_client(websocket, path):
    print("Client connected")
    # Client mesajlarını dinle
    client_task = asyncio.create_task(handle_messages(websocket))
    # Veri göndermeyi başlat
    sender_task = asyncio.create_task(send_data(websocket))
    
    try:
        await asyncio.gather(client_task, sender_task)
    except websockets.exceptions.ConnectionClosed:
        print("Client disconnected")
    finally:
        client_task.cancel()
        sender_task.cancel()

async def handle_messages(websocket):
    try:
        async for message in websocket:
            print(f"Received message: {message}")
            if message == "POWER_ON":
                detector_state["is_on"] = True
                await websocket.send(json.dumps({"status": "ON"}))
            elif message == "POWER_OFF":
                detector_state["is_on"] = False
                await websocket.send(json.dumps({"status": "OFF"}))
            elif message == "CALIBRATE":
                # Kalibrasyon simülasyonu
                await websocket.send(json.dumps({"status": "CALIBRATED"}))
    except websockets.exceptions.ConnectionClosed:
        pass

async def main():
    server = await websockets.serve(handle_client, "localhost", 8081)
    print("WebSocket server started on ws://localhost:8081")
    await server.wait_closed()

if __name__ == "__main__":
    asyncio.run(main()) 