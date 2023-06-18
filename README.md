# IntelliNest

## Description
IntelliNest is a native iOS application that leverages the power of the popular open-source home automation platform, Home Assistant, to control a variety of smart home devices and aims to replace the web-based Home Assitant app. The application is written in Swift/SwiftUI. My hope is that this repo will help you create your own native iOS app, I think the easiest approach is to familiarise yourself with this repo and then remove the views/viewmodels and start building your own based on the same architecture as this app. 
With chatGPT I think this would be doable even if you are not a iOS developer but you will need some experience in software development.

## Supported features
1. rest API and Websocket support
2. Local and remote connection depending on if counter.test88338833 is accessible or not using the local url
3. Heaters - with timer functionality
4. Car - Specifically E-niro but should be easily replaceable
5. Door locks
6. Roborock
7. CCTV - Using snapshot images but prepared for VLCMediaKit but the loading times were too long
8. Lights - Sliders to set the brightness
9. NFC tags - Set up automation in Shortcuts that call the intent in app (Storage lock and toggle monitor)
10. Remote logging using ShipBookSDK
11. User management - Used for logging and custom HomeView

## Getting Started
1. Clone the repository using `git clone https://github.com/TobiasLaross/IntelliNest.git`
2. Open the project in Xcode
3. Replace the bundle identifier (and optionally app name) to match your
4. Create a file named IntelliNest-Info.xcconfig and paste in the contents from Github-Info.xcconfig, you will modify the contents based on what functionality you will use.
5. Update the entityIds with your entities and remove the ones you don't want to use.
6. Modify the HomeView according to your needs.
7. Use the compiler to find the parts you are missing or the classes you need to delete.
9. Run the project on your preferred iOS simulator or device

## Contributions
IntelliNest is an open-source project and welcomes contributions. Please feel free to fork the repository and submit pull requests for any enhancements or features you think are useful. Try to make contribution generic enough or specific for this project that others might find useful.

## Licensing
IntelliNest is licensed under the terms of the MIT license. This license grants permission for the software to be used, copied, modified, merged, published, distributed, sublicensed, and/or sold.

## Special Thanks
A heartfelt thank you to Alex for suggesting the memorable name 'IntelliNest'.

