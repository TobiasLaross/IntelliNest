# IntelliNest

## Description
IntelliNest is a native iOS application that leverages the power of the popular open-source home automation platform, Home Assistant, to control a variety of smart home devices and aims to replace the web-based Home Assitant app. The application is written in Swift/SwiftUI. My hope is that this repo will help you create your own native iOS app, I think the easiest approach is to familiarise yourself with this repo and then remove the views/viewmodels and start building your own based on the same architecture as this app. 
With chatGPT I think this would be doable even if you are not a iOS developer but you will need some experience in software development.

## Supported features
### Rest API and Websocket support
Will probably replace some views to only use websocket instead of the rest api.
### Dynamic connection
Changing between local and remote connection depending on if counter.test88338833 is accessible or not using the local url
### Heaters
 Controlling heaters functionality - Temperature, mode, fan, vertical and horisontal direction and timer functionality.
 <div style="display: flex; justify-content: space-around;">
  <img src="https://github.com/TobiasLaross/IntelliNest/blob/main/Images/Heater.PNG" alt="Heater Image" width="120" height="280"/>
  <img src="https://github.com/TobiasLaross/IntelliNest/blob/main/Images/Heater2.PNG" alt="Heater Image" width="120" height="280"/>
  <img src="https://github.com/TobiasLaross/IntelliNest/blob/main/Images/Heater3.PNG" alt="Heater Image" width="120" height="280"/>
 </div>
 
### Car
Climate handling and scheduling, refresh data, start/stop charging, lock/unlock doors and charger limit and battery info.
### Door locks
### Roborock
Info since the trash was emptied, map view start/paus, dock, locate and send to bin. Also buttons for each room (organized by floor plan)
### CCTV
Using snapshot images 4 fps. Fully implemented support to use VLCMediaKit but the loading times were too long and Pod file not installed. It support rtsp while using local connection and HLS through home assistant remote connection otherwise.
### Lights
Sliders to set the brightness, tappable sliders and bulb button above each room.
### NFC tags
Set up automation in Shortcuts that call the intent in app (Storage lock and toggle monitor)
### User management
Used for logging and custom HomeView
### Remote logging
ShipBookSDK log function extended to always include which user it was that logged

## Getting Started
1. Clone the repository using `git clone https://github.com/TobiasLaross/IntelliNest.git`
2. Open the project in Xcode
3. Replace the bundle identifier to match yours (and optionally app name)
4. Create a file named IntelliNest-Info.xcconfig and paste in the contents from Github-Info.xcconfig, you will modify the contents based on what functionality you will use.
5. Update the entityIds with your entities and remove the ones you don't want to use.
6. Modify the HomeView according to your needs.
7. Use the compiler to find the parts you are missing or the classes you need to delete.
9. Run the project on your preferred iOS simulator or device

## Contributions
IntelliNest is an open-source project and welcomes contributions. Please feel free to fork the repository and submit pull requests for any enhancements or features you think are useful. Try to make contribution generic enough or specific for this project that others might find useful.
A thank you to @alexEkdahl for suggesting the name 'IntelliNest'.

## Licensing
IntelliNest is licensed under the terms of the MIT license. This license grants permission for the software to be used, copied, modified, merged, published, distributed, sublicensed, and/or sold.
