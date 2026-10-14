import { useEffect, useState } from "react";
import { Linking } from "react-native";
import { StatusBar } from "expo-status-bar";
import { E2E } from "./src/E2E";
import { Playground } from "./src/Playground";

// gltransitions://e2e opens the on-device checks (see src/E2E.tsx); otherwise the playground.
export default function App() {
  const [url, setUrl] = useState<string | null | undefined>(undefined);
  useEffect(() => {
    Linking.getInitialURL()
      .then(setUrl)
      .catch(() => setUrl(null));
    const subscription = Linking.addEventListener("url", (event) => setUrl(event.url));
    return () => subscription.remove();
  }, []);
  if (url === undefined) return null;
  return (
    <>
      <StatusBar style="light" />
      {url?.includes("e2e") ? <E2E key={url} /> : <Playground />}
    </>
  );
}
