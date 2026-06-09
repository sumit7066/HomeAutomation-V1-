# Google Assistant via IFTTT Webhooks Setup Guide

This guide describes how to trigger your smart home relays from Google Assistant using **IFTTT (If This Then That)**. This bypasses the complex Google account linking, OAuth2 flows, and HTTPS domain validation.

---

## 🛠️ Step 1: Obtain Your Device Token
1. Open your SmartHome Web Dashboard.
2. Find the device you want to control.
3. Copy its **16-character Device Token** (e.g. `A1B2C3D4E5F6G7H8`).

---

## 🌐 Step 2: Keep Server Running & Tunnel it
Google (via IFTTT) needs a public link to call your backend:
1. Ensure your backend server is running locally on port `3000` (`npm start`).
2. Open a terminal and run your ngrok tunnel:
   ```bash
   ngrok http 3000
   ```
3. Copy the secure HTTPS URL (e.g., `https://a1b2-34-56-78.ngrok-free.app`).
   *Note: If you restart ngrok, this URL changes and must be updated in your IFTTT applets.*

---

## 📲 Step 3: Create an Applet in IFTTT

1. Go to [IFTTT.com](https://ifttt.com/) and log in (or create a free account).
2. Click **Create** in the top right.
3. Next to **If This**, click **Add**.
4. Search for **Google Assistant** and select it.
5. Choose the trigger: **Activate Scene** (This is the standard trigger for Google Assistant v2).
6. Under **What scene do you want to activate?**, type the trigger phrase. E.g.:
   * Type: `turn on light one` (or `relay one on`)
7. Click **Create trigger**.

---

## 🔌 Step 4: Add the Webhook Action

1. Next to **Then That**, click **Add**.
2. Search for **Webhooks** and select **Make a web request**.
3. Configure the fields exactly as follows:
   * **URL**: Paste your ngrok HTTPS URL followed by `/api/webhook/control`:
     ```text
     https://YOUR_NGROK_SUBDOMAIN.ngrok-free.app/api/webhook/control
     ```
   * **Method**: `POST`
   * **Content Type**: `application/json`
   * **Additional Headers**: (Leave blank)
   * **Body**: Enter the JSON data specifying your Device Token, the Relay Index (starts at `0` for Relay 1), and the State (`"on"` or `"off"`):
     ```json
     {
       "token": "YOUR_16_CHAR_DEVICE_TOKEN",
       "relay": 0,
       "state": "on"
     }
     ```
     *(Make sure to replace `YOUR_16_CHAR_DEVICE_TOKEN` with your actual device token from Step 1).*
4. Click **Create action** and then **Continue**.
5. Give your Applet a descriptive name (e.g., *Google Assistant Turn On Relay 1*) and click **Finish**.

---

## 🗣️ Step 5: Test Voice Commands
Now, on any Google Nest Speaker, Android phone, or iPhone with the Google Assistant app signed into the same Google account:

1. Say: *"Hey Google, activate turn on light one"* (or whatever phrase you set in Step 3).
2. Google Assistant will confirm: *"Activating turn on light one"*.
3. Your backend server console will log the command, and your ESP32 relay will instantly toggle ON!

---

### 💡 To Turn Relays OFF:
To turn the relay OFF, simply create a second IFTTT applet:
* **Trigger Phrase**: `turn off light one`
* **Webhook Body**:
  ```json
  {
    "token": "YOUR_16_CHAR_DEVICE_TOKEN",
    "relay": 0,
    "state": "off"
  }
  ```
