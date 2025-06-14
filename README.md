# 📍 PinPoint

PinPoint is a full-featured iOS mobile application that allows users to seamlessly manage social groups, share locations, view activity feeds, and interact through an intuitive interface. The app was developed as a group project using SwiftUI and Firebase, with each team member owning specific features. My primary contributions include the Activity Feed module, cross-tab post navigation, real-time synchronization, and UI enhancements for group management.

## 📹 Group Demo
- Link to group introduction and app demo: https://www.youtube.com/watch?v=3lsWDmgRwEQ

## 🔑 Key Features

- **User Authentication**
  - Secure account creation and login via Firebase Authentication
  - Password reset and profile management
- **Group Management**
  - Create, join, and leave groups with customized group profiles
  - View group details and members with responsive UI displaying member avatars and names
- **Activity Feed (My Core Contribution)**
  - Real-time updates of activity events such as pin creation, group joins, and reviews
  - Like/unlike posts with instant UI updates using Firebase Firestore's real-time listeners
  - Dynamic timestamp displays (seconds, minutes, hours ago)
  - Cross-tab navigation: tapping activity items routes to relevant details across app tabs
- **Interactive Map**
  - Browse map pins representing group-shared locations
  - Navigate to pin details directly from the Activity Feed
- **Settings**
  - Edit user profile information
  - Manage passwords and authentication state
  - Sign out functionality

## 🛠 Tech Stack

- **Language:** Swift, SwiftUI
- **Backend:** Firebase Firestore (NoSQL database), Firebase Authentication
- **State Management:** SwiftUI State, Combine
- **Image Loading & Caching:** AsyncImage
- **Version Control:** Git, GitHub

## 📂 Architecture Highlights

- Modular SwiftUI components with clean MVVM-inspired design
- Firebase Firestore used for real-time, cloud-hosted data synchronization across multiple user sessions
- Secure authentication flows with session management via Firebase Authentication
- Responsive and reactive UI leveraging SwiftUI's declarative data binding

## ✨ Future Improvements

- Push notifications for group invites and activity events
- Enhanced pin categorization and tagging
- Offline support with local caching
- Admin features for group moderators

## 👨‍💻 Author Contributions

- **Activity Feed:** Real-time feed functionality, post detail navigation, like system, timestamp logic, Firestore integration
- **Groups UI:** Group member list
