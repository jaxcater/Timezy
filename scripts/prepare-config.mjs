import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const config = path.join(root, 'Config');
const resources = path.join(root, 'Sources/Resources');
fs.mkdirSync(config, { recursive: true });
fs.mkdirSync(resources, { recursive: true });
const source = path.join(config, 'GoogleService-Info.plist');
const destination = path.join(resources, 'GoogleService-Info.plist');
let reversedClient = 'com.timezy.unconfigured';
const escapeXML = value => value.replaceAll('&', '&amp;').replaceAll('<', '&lt;').replaceAll('>', '&gt;').replaceAll('"', '&quot;');
if (fs.existsSync(source)) {
  const xml = fs.readFileSync(source, 'utf8');
  const read = key => xml.match(new RegExp(`<key>${key}</key>\\s*<string>([^<]+)</string>`))?.[1];
  reversedClient = read('REVERSED_CLIENT_ID');
  if (!reversedClient || !/^[a-zA-Z0-9.-]+$/.test(reversedClient) || !read('CLIENT_ID') || !read('GOOGLE_APP_ID')) {
    throw new Error('Firebase plist thiếu CLIENT_ID / REVERSED_CLIENT_ID / GOOGLE_APP_ID. Bật Google Auth rồi tải lại plist XML.');
  }
  if (read('BUNDLE_ID') !== 'com.timezy.app') {
    throw new Error('BUNDLE_ID phải là com.timezy.app; nếu đổi ID, cập nhật project.yml và script này cùng Firebase.');
  }
  fs.copyFileSync(source, destination);
  console.log('Firebase: cấu hình đã được chuẩn bị.');
} else {
  if (fs.existsSync(destination)) fs.unlinkSync(destination);
  console.log('Firebase: chưa cấu hình; build vẫn dùng được lịch trên máy.');
}
fs.writeFileSync(path.join(config, 'Info.plist'), `<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleDisplayName</key><string>Timezy</string>
<key>CFBundleName</key><string>$(PRODUCT_NAME)</string>
<key>CFBundleIdentifier</key><string>$(PRODUCT_BUNDLE_IDENTIFIER)</string>
<key>CFBundleExecutable</key><string>$(EXECUTABLE_NAME)</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleShortVersionString</key><string>$(MARKETING_VERSION)</string>
<key>CFBundleVersion</key><string>$(CURRENT_PROJECT_VERSION)</string>
<key>CFBundleDevelopmentRegion</key><string>vi</string>
<key>LSRequiresIPhoneOS</key><true/>
<key>UILaunchScreen</key><dict/>
<key>UIUserInterfaceStyle</key><string>Dark</string>
<key>UISupportedInterfaceOrientations</key><array><string>UIInterfaceOrientationPortrait</string></array>
<key>NSMicrophoneUsageDescription</key><string>Timezy dùng micro khi bạn chọn nói để thêm lịch trình.</string>
<key>NSSpeechRecognitionUsageDescription</key><string>Timezy chuyển lời nói tiếng Việt thành văn bản để bạn kiểm tra trước khi tạo lịch.</string>
<key>CFBundleURLTypes</key><array><dict><key>CFBundleURLSchemes</key><array><string>${escapeXML(reversedClient)}</string></array></dict></array>
<key>ITSAppUsesNonExemptEncryption</key><false/>
</dict></plist>
`);
console.log('Đã tạo Config/Info.plist.');
