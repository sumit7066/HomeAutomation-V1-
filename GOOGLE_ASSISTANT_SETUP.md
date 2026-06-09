# Google Assistant Smart Home Voice Control Setup Guide

This guide walks you through the step-by-step process of integrating your smart home project (Node.js backend + Vite/React client + ESP32 relays) with **Google Assistant** and **Google Home**. 

Since the project already implements standard Smart Home OAuth2 protocols and fulfillment endpoints (`SYNC`, `QUERY`, `EXECUTE`, `DISCONNECT`), this guide focuses on exposing your local development setup and configuring the **Google Actions Console**.

---

## 🛠️ Prerequisites

1. **Active Project**: Make sure your local MongoDB, server (`server.js` on port `3000`), and React client (`App.jsx` on port `5173`) are running.
2. **ngrok**: Install `ngrok` (free) to securely expose your local backend to the internet, allowing Google's cloud servers to call your fulfillment endpoints.
3. **Google Account**: An active Google account to access the developer consoles.

---

## 🌐 Step 1: Expose Your Local Server with ngrok

Google's servers must be able to hit your local server endpoints. Since local ports (`http://localhost:3000`) are private, we will create a secure public tunnel.

1. Download and authenticate `ngrok` if you haven't already.
2. Run the following command in your terminal to tunnel your Node.js backend:
   ```bash
   ngrok http 3000
   ```
3. Copy the generated **Forwarding HTTPS URL** (e.g., `https://a1b2-34-56-78-90.ngrok-free.app`).
   > [!IMPORTANT]
   > Keep this terminal open! If you restart ngrok, it will assign a new URL, and you will need to update your endpoints in the Google Console.
4. Verify it's working by visiting the ngrok URL in your browser. You should see your server running or a basic response.

---

## 🏗️ Step 2: Create a Project in Google Actions Console

1. Visit the [Google Actions Console](https://console.actions.google.com/).
2. Click **New Project** and agree to the Terms of Service.
3. Enter a project name (e.g., `My DIY Smart Home`) and click **Create Project**.
4. Scroll down to the bottom of the page and click **Are you looking for device registration? Click here to go to the smart home developer console**.
5. Alternatively, visit the [Google Home Console](https://home.console.google.com/) directly, which is the modern hub for Smart Home projects.
6. Click **Add project** -> **Import Action from Actions Console** -> Choose the project you just created -> Click **Import**.

---

## 🔗 Step 3: Configure your Smart Home Integration

In the Google Home/Actions console:

### 1. Set Up Fulfillment URL
1. Navigate to **Develop** -> **Actions** (or Actions Configuration).
2. For **Fulfillment URL**, paste your ngrok HTTPS URL followed by `/api/fulfillment`:
   ```text
   https://YOUR_NGROK_SUBDOMAIN.ngrok-free.app/api/fulfillment
   ```
3. Click **Save**.

### 2. Configure OAuth2 Account Linking
Google needs to link Google Home accounts to your dashboard accounts using standard OAuth2.

1. Navigate to **Develop** -> **Account Linking**.
2. Set the following fields:
   * **Client ID**: `google-home-client-id` (You can use this default or any unique string)
   * **Client Secret**: `google-home-client-secret` (Any string - the backend supports flexible verification for DIY setups)
   * **Authorization URL**: 
     Enter your Client React App URL (Vite dev server) so the Google Home App redirects the user to your login screen:
     * If logging in on the *same machine/simulator*: `http://localhost:5173`
     * If linking on your *physical phone*: Tunnel your client on port `5173` with `ngrok http 5173` and use the resulting client HTTPS URL (e.g., `https://YOUR_CLIENT_NGROK.ngrok-free.app`).
   * **Token URL**:
     ```text
     https://YOUR_NGROK_SUBDOMAIN.ngrok-free.app/api/oauth/token
     ```
3. Set the **Scopes** (optional): Leave empty or add `smart-home`.
4. Click **Save**.

---

## 📱 Step 4: Link in the Google Home App

Now that your integration is configured in the cloud, you can test it on your physical phone!

1. Install the **Google Home App** on your Android or iOS device.
2. Ensure you are signed in with the **same Google account** used for the Actions/Home Console.
3. In the Home App:
   * Tap the **"+" (plus)** icon in the top-left or go to **Devices -> Add**.
   * Select **Works with Google**.
   * Search for your project name. It will be prefixed with `[test]` (e.g. `[test] My DIY Smart Home`).
   * Tap it. This will open your web client's login page in your mobile browser.
4. **Log in** with your registered SmartHome account credentials.
5. You will see a beautiful glassmorphic **Link to Google Home** page. Tap **Authorize**.
6. Google Home will fetch your registered devices (from the ESP32 main board/relays) and present them! You can assign them to rooms (e.g. Living Room, Bedroom).

---

## 🗣️ Step 5: Speak Voice Commands!

Your ESP32 relays are now synced with Google Assistant. You can control them using natural voice commands on any Google Nest speaker, Android phone, or the Google Assistant app:

* 🗣️ *"Hey Google, turn on Living Room Relay 1"*
* 🗣️ *"Hey Google, is Relay 2 turned off?"*
* 🗣️ *"Hey Google, turn off everything"*

---

## 🔍 Troubleshooting & Verification

* **Device is Offline in Google Home**:
  Google checks device status via `/api/fulfillment` using the `action.devices.QUERY` intent.
  * Check your Node.js console log to see if Google is sending query requests.
  * Ensure your ESP32 is powered on, connected to WiFi, and pinging `/api/device/commands` (the cloud sync interval is set to 500ms).
  * In the web dashboard, confirm the device status badge shows **Online** (meaning it has updated the server in the last 30 seconds).
* **ngrok Tunnel Reconnects**:
  If your ngrok tunnel closes, your public URL changes. You must update both the **Fulfillment URL** and the **Token URL** in the Google Console with the new ngrok URL.
* **Inspect Google Requests**:
  Add `console.log(JSON.stringify(req.body, null, 2))` inside the `/api/fulfillment` route in `server.js` to inspect the exact request payloads Google sends you. It's a great way to debug!
* **Unlinking Account**:
  If you disconnect the app inside the Google Home settings, our backend automatically receives the `action.devices.DISCONNECT` intent and deletes the associated refresh tokens, ensuring clean state.
