# Progress entry design review — 2026-09-16

Figma file: M37Q2Q2mOe0UwzTWeA2Ofl.
Weight: 204:57294 / 204:57837; weight date: 204:57317 / 204:57860.
Workout: 204:57345 / 204:57888; workout date: 204:57376 / 204:57919.
Camera quality reference: 204:57955.

Implemented fixed UIKit point dimensions, centered weight and baseline-aligned unit,
visible slider rail and ticks, compact date badge with padding, elevated dark cards,
16 pt input corners, secondary input captions, native 216 pt duration picker,
localized exercise chips, translucent date sheet, 24 pt calendar-to-button gap,
and 26 pt bottom inset inside the floating sheet. Calendar opens the selected month.
Native calendar selection and duration wheels retain the platform appearance.

Validation: iPhone 17 Pro simulator / iOS 26.5, light and dark screenshots.
Xcode build succeeded. Three existing tests passed: ProgressChromeTests,
weight conversion round trip, and progress photo persistence.

Camera audit (no capture-code change needed): ProgressPhotoCameraViewController
calls captureFullFramePhoto; CameraFoodPhotoCapturer uses the photo preset,
CameraCaptureTuning requests the largest supported dimensions of the active format
and quality prioritization. AVCapturePhoto.fileDataRepresentation is passed directly
to SaveProgressPhotoUseCase and LocalImageFileStore, which writes the bytes atomically.
No resize/recompression on the camera path. This verifies configured quality, not
hardware megapixel output: the simulator has no camera. Gallery import separately
encodes JPEG at 0.9 and is not the camera capture path.
