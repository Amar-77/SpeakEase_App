const { onDocumentCreated } = require("firebase-functions/v2/firestore");
const { setGlobalOptions } = require("firebase-functions/v2");
const admin = require("firebase-admin");

admin.initializeApp();

// Match this to your Firestore region
setGlobalOptions({ region: "asia-south1" });

//exports.sendAssignmentNotification = onDocumentCreated("assignments/{assignmentId}", async (event) => {
//  const snapshot = event.data;
//  if (!snapshot) return; // Safety check 1
//
//  const data = snapshot.data();
//  const classId = data.class_id;
//  const title = data.title;
//
//  // Safety check 2: Prevents the function from crashing if data is missing
//  if (!classId || !title) {
//    console.log("Missing class_id or title. Skipping notification.");
//    return;
//  }
//
//  const message = {
//    notification: {
//      title: "New Assignment! 📚",
//      body: `Your teacher posted: ${title}`,
//    },
//    topic: classId,
//  };
//
//  try {
//    const response = await admin.messaging().send(message);
//    console.log(`✅ Success: Notification sent to ${classId}. ID: ${response}`);
//  } catch (error) {
//    console.error("❌ FCM Error:", error);
//  }
//});