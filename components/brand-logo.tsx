import Image from "next/image";

import horizontalDark from "@/public/brand/ortusolis-logo-horizontal-dark.png";
import horizontalNegative from "@/public/brand/ortusolis-logo-horizontal-negative.png";
import verticalNegative from "@/public/brand/ortusolis-logo-vertical-negative.png";
import verticalPositive from "@/public/brand/ortusolis-logo-vertical-positive.png";

type BrandLogoVariant =
  | "horizontal-dark"
  | "horizontal-negative"
  | "vertical-negative"
  | "vertical-positive";

type BrandLogoProps = {
  className?: string;
  preload?: boolean;
  variant?: BrandLogoVariant;
};

const logoByVariant = {
  "horizontal-dark": horizontalDark,
  "horizontal-negative": horizontalNegative,
  "vertical-negative": verticalNegative,
  "vertical-positive": verticalPositive,
} satisfies Record<BrandLogoVariant, typeof horizontalDark>;

export function BrandLogo({
  className,
  preload = false,
  variant = "horizontal-dark",
}: BrandLogoProps) {
  const orientation = variant.startsWith("horizontal")
    ? "horizontal"
    : "vertical";

  return (
    <Image
      alt="Ortusolis — Inovação em Ozônio"
      className={`brand-logo brand-logo-${orientation}${className ? ` ${className}` : ""}`}
      preload={preload}
      sizes={
        orientation === "horizontal"
          ? "(max-width: 608px) 176px, 208px"
          : "(max-width: 608px) 192px, 224px"
      }
      src={logoByVariant[variant]}
    />
  );
}
