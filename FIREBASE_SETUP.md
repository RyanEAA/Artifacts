# Firebase Setup Guide for Dynamic Artifact Syncing

This guide explains the Firebase structure needed to support automatic artifact saving and loading with real-time syncing.

## Firestore Collections

### 1. `artifacts` Collection (NEW - Required)

This collection stores all AR artifacts (3D models and annotations) that are placed in scenes.

**Document Structure:**
```javascript
artifacts/{artifactId}
{
  id: string,                    // UUID string (same as document ID)
  type: string,                  // "model" or "annotation"
  sceneId: string,              // UUID of the scene this artifact belongs to
  ownerUid: string,             // Firebase Auth UID of the user who created it
  createdAt: timestamp,          // When the artifact was first created
  updatedAt: timestamp,          // Last update time (auto-updated on changes)
  
  // Model-specific fields (only present if type == "model")
  modelName: string?,            // Name of the 3D model (e.g., "toyplane")
  
  // Annotation-specific fields (only present if type == "annotation")
  annotationText: string?,       // Text content of the annotation
  
  // Transform data (always present)
  transform: array<number>,       // 16-element array representing 4x4 transform matrix
  position: array<number>        // [x, y, z] position for easier querying
}
```

**Example Document:**
```javascript
artifacts/abc123-def456-ghi789
{
  id: "abc123-def456-ghi789",
  type: "model",
  sceneId: "scene-uuid-here",
  ownerUid: "user-firebase-uid",
  createdAt: Timestamp(2025, 1, 15, 10, 30, 0),
  updatedAt: Timestamp(2025, 1, 15, 10, 35, 0),
  modelName: "toyplane",
  transform: [1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0.5, 1.2, -0.3, 1],
  position: [0.5, 1.2, -0.3]
}
```

### 2. `scenes` Collection (Existing)

This collection stores metadata about AR scenes (world maps).

**Document Structure:**
```javascript
scenes/{sceneId}
{
  ownerUid: string,              // Firebase Auth UID of the scene owner
  name: string,                  // Scene name (e.g., "My Scene")
  storagePath: string,           // Path in Firebase Storage (e.g., "users/{uid}/scenes/{sceneId}.worldmap")
  updatedAt: timestamp,          // Last update time
  bytes: number                  // Size of the world map file in bytes
}
```

### 3. `models` Collection (Existing)

This collection stores available 3D models that can be placed.

**Document Structure:**
```javascript
models/{modelName}
{
  name: string,                  // Model identifier
  category: string,              // "table", "chair", "decor", "light", "toy"
  scaleCompensation: number      // Scale factor (default: 1.0)
}
```

### 4. `users` Collection (Existing - if used)

Stores user profile information.

**Document Structure:**
```javascript
users/{userId}
{
  username: string,
  email: string,
  createdAt: timestamp,
  lastActive: timestamp,
  profilePictureURL: string?
}
```

## Firebase Storage Structure

### Storage Paths:
```
users/
  {uid}/
    scenes/
      {sceneId}.worldmap    // ARWorldMap binary data
    models/
      {modelName}.usdz      // 3D model files
    thumbnails/
      {modelName}.jpg       // Model thumbnails
```

## Firestore Security Rules

Add these rules to your Firestore database:

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    
    // Helper function to check if user is authenticated
    function isAuthenticated() {
      return request.auth != null;
    }
    
    // Helper function to check if user owns a resource
    function isOwner(userId) {
      return isAuthenticated() && request.auth.uid == userId;
    }
    
    // Artifacts collection - allows read/write for authenticated users
    // Real-time syncing requires read access for all users viewing the same scene
    match /artifacts/{artifactId} {
      // Allow read if authenticated (needed for real-time syncing)
      allow read: if isAuthenticated();
      
      // Allow create if authenticated
      allow create: if isAuthenticated() 
        && request.resource.data.ownerUid == request.auth.uid
        && request.resource.data.sceneId is string
        && request.resource.data.type in ['model', 'annotation'];
      
      // Allow update if user owns the artifact
      allow update: if isAuthenticated() 
        && (resource.data.ownerUid == request.auth.uid 
            || request.resource.data.ownerUid == request.auth.uid);
      
      // Allow delete if user owns the artifact
      allow delete: if isAuthenticated() 
        && resource.data.ownerUid == request.auth.uid;
    }
    
    // Scenes collection
    match /scenes/{sceneId} {
      // Allow read if authenticated
      allow read: if isAuthenticated();
      
      // Allow create/update if authenticated and user owns the scene
      allow create, update: if isAuthenticated() 
        && request.resource.data.ownerUid == request.auth.uid;
      
      // Allow delete if user owns the scene
      allow delete: if isAuthenticated() 
        && resource.data.ownerUid == request.auth.uid;
    }
    
    // Models collection - read-only for authenticated users
    match /models/{modelId} {
      allow read: if isAuthenticated();
      allow write: if false; // Only admins can modify models (set up admin check if needed)
    }
    
    // Users collection
    match /users/{userId} {
      allow read: if isAuthenticated();
      allow create, update: if isAuthenticated() && request.auth.uid == userId;
      allow delete: if isAuthenticated() && request.auth.uid == userId;
    }
  }
}
```

## Firebase Storage Security Rules

Add these rules to your Firebase Storage:

```javascript
rules_version = '2';
service firebase.storage {
  match /b/{bucket}/o {
    
    // Helper function
    function isAuthenticated() {
      return request.auth != null;
    }
    
    // User-specific files
    match /users/{userId}/{allPaths=**} {
      // Users can read their own files and files of others (for sharing)
      allow read: if isAuthenticated();
      
      // Users can only write to their own directory
      allow write: if isAuthenticated() && request.auth.uid == userId;
    }
  }
}
```

## Required Firestore Indexes

You need to create composite indexes for efficient queries:

### 1. Artifacts by Scene ID
- **Collection:** `artifacts`
- **Fields:**
  - `sceneId` (Ascending)
  - `updatedAt` (Descending) - Optional, for sorting

**How to create:**
1. Go to Firebase Console → Firestore Database → Indexes
2. Click "Create Index"
3. Collection ID: `artifacts`
4. Add fields:
   - `sceneId` - Ascending
   - `updatedAt` - Descending (optional)
5. Click "Create"

### 2. Scenes by Owner and Update Time
- **Collection:** `scenes`
- **Fields:**
  - `ownerUid` (Ascending)
  - `updatedAt` (Descending)

**How to create:**
1. Go to Firebase Console → Firestore Database → Indexes
2. Click "Create Index"
3. Collection ID: `scenes`
4. Add fields:
   - `ownerUid` - Ascending
   - `updatedAt` - Descending
5. Click "Create"

## Setup Steps

1. **Create the `artifacts` collection:**
   - The collection will be created automatically when the first artifact is saved
   - No manual setup needed

2. **Set up Firestore Security Rules:**
   - Go to Firebase Console → Firestore Database → Rules
   - Paste the security rules provided above
   - Click "Publish"

3. **Set up Firebase Storage Security Rules:**
   - Go to Firebase Console → Storage → Rules
   - Paste the storage rules provided above
   - Click "Publish"

4. **Create Firestore Indexes:**
   - Follow the steps above to create the required indexes
   - Indexes may take a few minutes to build

5. **Test the Setup:**
   - Run your app and place an artifact
   - Check Firestore Console to verify the artifact document was created
   - Test real-time syncing by opening the same scene on multiple devices

## Data Flow

1. **Placing an Artifact:**
   - User places a model/annotation → App creates `ArtifactData` → Saves to `artifacts/{artifactId}`

2. **Updating an Artifact:**
   - User moves/edits artifact → App updates `transform` and `updatedAt` → Updates `artifacts/{artifactId}`

3. **Real-time Syncing:**
   - App sets up listener on `artifacts` collection filtered by `sceneId`
   - When any user updates an artifact, all listeners receive the update
   - App automatically adds/updates/removes artifacts in the AR scene

4. **Deleting an Artifact:**
   - User deletes artifact → App deletes `artifacts/{artifactId}` → All listeners receive deletion

## Important Notes

- **Scene IDs:** Scene IDs are automatically generated as UUIDs and stored in UserDefaults
- **Artifact IDs:** Each artifact gets a unique UUID as its document ID
- **Real-time Listeners:** The app automatically sets up listeners when a scene is loaded
- **Transform Format:** Transforms are stored as 16-element arrays (4x4 matrix flattened)
- **Position Field:** The `position` field is extracted from the transform for easier querying (optional but recommended)

## Troubleshooting

- **"Missing or insufficient permissions"**: Check Firestore security rules
- **"Index required"**: Create the composite indexes listed above
- **Real-time updates not working**: Verify the listener is set up and security rules allow reads
- **Artifacts not loading**: Check that `sceneId` matches between artifacts and scenes

