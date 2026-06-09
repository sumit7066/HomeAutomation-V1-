# Google Assistant Voice Control Setup via Sinric Pro (Free)

This guide walks you through setting up voice control using **Sinric Pro** (completely free for up to 3 devices/boards). This is a direct, robust alternative to Google Home Dev Console or IFTTT.

---

## 🛠️ Step 1: Install the SinricPro Library
In the Arduino IDE:
1. Open **Sketch** -> **Include Library** -> **Manage Libraries...**
2. Search for `SinricPro` and click **Install**. (Make sure to install any dependencies it requests, such as WebSockets or ArduinoJson if you don't already have them).

---

## 🔑 Step 2: Sign Up and Create Devices in Sinric Pro
1. Go to [Sinric Pro Portal](https://sinric.pro) and register for a free account.
2. Go to the dashboard and copy your **App Key** and **App Secret**.
3. Go to **Devices** on the left menu.
4. Click **Add Device**:
   * **Device Name**: Give it a name (e.g. `Light 1` or `Relay 1`).
   * **Description**: Optional.
   * **Device Type**: Select **Switch**.
   * Click **Save** (this will generate a unique **Device ID**).
5. Repeat Step 4 for each of your relays (e.g. up to 8 relays). Note down the **Device ID** generated for each switch.

---

## 💻 Step 3: Insert Your Keys into the ESP32 Code
Open [main_board.ino](file:///c:/Users/sumit/Desktop/My%20locker/projects/HomeAutomaito%20antigravity%20V2/esp32/main_board/main_board.ino) and look at the top of the file:

1. Replace `YOUR-SINRIC-APP-KEY` and `YOUR-SINRIC-APP-SECRET` with the credentials from Step 2:
   ```cpp
   #define APP_KEY       "YOUR_ACTUAL_APP_KEY"
   #define APP_SECRET    "YOUR_ACTUAL_APP_SECRET"
   ```
2. Put the generated Device IDs into the `SINRIC_SWITCH_IDS` array in the order of your relays:
   ```cpp
   const char* SINRIC_SWITCH_IDS[8] = {
     "DEVICE_ID_FOR_RELAY_1",
     "DEVICE_ID_FOR_RELAY_2",
     "DEVICE_ID_FOR_RELAY_3",
     "DEVICE_ID_FOR_RELAY_4",
     "DEVICE_ID_FOR_RELAY_5",
     "DEVICE_ID_FOR_RELAY_6",
     "DEVICE_ID_FOR_RELAY_7",
     "DEVICE_ID_FOR_RELAY_8"
   };
   ```
3. Upload the modified code to your ESP32 Main Board.

---

## 📱 Step 4: Link Sinric Pro to Google Assistant / Google Home
Now you link the pre-approved Sinric Pro smart home action in your phone app:

1. Open the **Google Home App** on your mobile phone.
2. Tap **Add (+)** -> **Works with Google**.
3. Search for **Sinric Pro** and select it.
4. Log in using your **Sinric Pro credentials** (email/password).
5. All your created switches will instantly sync into your Google Home app! You can rename them (e.g., "Living Room Fan") or place them in rooms.

---

## 🗣️ Step 5: Start Controlling by Voice!
Speak standard voice commands directly to your phone or a Nest speaker:
* 🗣️ *"Hey Google, turn on Light 1"*
* 🗣️ *"Hey Google, turn off Relay 2"*
* 🗣️ *"Hey Google, check if Switch 3 is turned off"*

*Because of our bidirectional state sync implementation, if you toggle a relay via physical switches, your remote board, or the web dashboard, the status inside the Google Home App will instantly update to match!*
