// app/providers.tsx
"use client";

import { ChakraProvider, extendTheme } from "@chakra-ui/react";

// Define a custom theme
const theme = extendTheme({
  styles: {
    global: {
      body: {
        color: "#ffffff",
        backgroundColor: "#01011f",
      },
    },
  },
});

export function Providers({ children }) {
  // Provide the custom theme to your application
  return <ChakraProvider theme={theme}>{children}</ChakraProvider>;
}
