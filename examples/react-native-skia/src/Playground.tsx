import { useEffect, useState } from "react";
import { FlatList, Pressable, StyleSheet, Text, View, useWindowDimensions } from "react-native";
import { Canvas } from "@shopify/react-native-skia";
import { Easing, useSharedValue, withRepeat, withTiming } from "react-native-reanimated";
import { Transition } from "@gl-transitions/react-native-skia";
import transitions from "gl-transitions";
import { fromImage, texturesFor, toImage } from "./images";

// Pick a transition: it plays back and forth, animated by Reanimated on the UI thread.
export function Playground() {
  const { width } = useWindowDimensions();
  const [name, setName] = useState("crosswarp");
  const progress = useSharedValue(0);
  useEffect(() => {
    progress.value = withRepeat(withTiming(1, { duration: 1500, easing: Easing.inOut(Easing.cubic) }), -1, true);
  }, [progress]);
  const transition = transitions.find((t) => t.name === name)!;
  const height = Math.round(width * 0.66);

  return (
    <View style={styles.screen}>
      <Canvas style={{ width, height }}>
        <Transition
          name={name}
          from={fromImage}
          to={toImage}
          textures={texturesFor(transition.textures)}
          progress={progress}
          width={width}
          height={height}
          fit="fill"
        />
      </Canvas>
      <Text style={styles.title}>{name}</Text>
      <Text style={styles.description}>{transition.description}</Text>
      <FlatList
        data={transitions}
        keyExtractor={(t) => t.name}
        renderItem={({ item }) => (
          <Pressable onPress={() => setName(item.name)} style={styles.item}>
            <Text style={[styles.itemText, item.name === name && styles.selected]}>{item.name}</Text>
          </Pressable>
        )}
      />
    </View>
  );
}

const styles = StyleSheet.create({
  screen: { flex: 1, backgroundColor: "#111", paddingTop: 48 },
  title: { color: "#fff", fontSize: 20, fontWeight: "600", marginHorizontal: 16, marginTop: 12 },
  description: { color: "#aaa", marginHorizontal: 16, marginBottom: 8 },
  item: { paddingVertical: 10, paddingHorizontal: 16 },
  itemText: { color: "#ddd", fontSize: 16 },
  selected: { color: "#6cf", fontWeight: "600" },
});
