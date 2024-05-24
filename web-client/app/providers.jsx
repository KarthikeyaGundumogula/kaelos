// providers.tsx
"use client";
import React from "react";
import { ChakraProvider, extendTheme } from "@chakra-ui/react";

// Define a custom theme
const theme = extendTheme({
  styles: {
    global: {
      body: {
        bg: "black",
        color: "white",
      },
      h1: {
        color: "blue.500",
      },
      h2: {
        color: "blue.500",
      },
      h3: {
        color: "blue.500",
      },
      h4: {
        color: "blue.500",
      },
      h5: {
        color: "blue.500",
      },
      h6: {
        color: "blue.500",
      },
    },
  },
});

export function Providers({ children }) {
  // Provide the custom theme to your application
  return <ChakraProvider theme={theme}>{children}</ChakraProvider>;
}
