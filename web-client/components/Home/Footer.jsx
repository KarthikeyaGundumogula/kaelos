// Footer.jsx
import React from "react";
import { Box, Flex, Text, Link } from "@chakra-ui/react";
import NextLink from "next/link";

const Footer = () => {
  return (
    <Box as="footer" bg="black" py={4} px={8}>
      <Flex justify="space-between" align="center">
        <Text color="white">
          &copy; {new Date().getFullYear()} Utopian Games. All rights reserved.
        </Text>
        <Flex align="center" spacing={4}>
          <NextLink href="/about" passHref>
            <Link color="blue.500">About</Link>
          </NextLink>
          <NextLink href="/contact" passHref>
            <Link color="blue.500">Contact</Link>
          </NextLink>
          <NextLink href="/privacy" passHref>
            <Link color="blue.500">Privacy</Link>
          </NextLink>
          <NextLink href="/terms" passHref>
            <Link color="blue.500">Terms</Link>
          </NextLink>
        </Flex>
      </Flex>
    </Box>
  );
};

export default Footer;
