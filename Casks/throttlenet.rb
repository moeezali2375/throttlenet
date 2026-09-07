cask "throttlenet" do
  version "1.0.0"
  sha256 "a69dfd26bb98f29e8b9981e75883f63d9252086341008ad96608f510733cc039"

  url "https://github.com/moeezali2375/throttlenet/releases/download/v#{version}/ThrottleNet-v#{version}-macOS.zip"
  name "ThrottleNet"
  desc "Native macOS per-process network monitor and bandwidth limiter"
  homepage "https://github.com/moeezali2375/throttlenet"

  depends_on macos: ">= :ventura"

  app "ThrottleNet.app"

  zap trash: [
    "~/Library/Preferences/com.throttlenet.app.plist",
    "~/Library/Application Support/ThrottleNet",
  ]
end
