const express = require("express");
const { rateLimit } = require("express-rate-limit");

const router = express.Router();
const cache = new Map();

const geocodingLimiter = rateLimit({
  windowMs: 1000,
  limit: 1,
  keyGenerator: () => "sawa-geocoding",
  standardHeaders: "draft-8",
  legacyHeaders: false,
  message: {
    status: "RATE_LIMIT_EXCEEDED",
    error_message: "Please wait before searching again.",
  },
});

router.get("/", geocodingLimiter, async (req, res) => {
  const address =
    typeof req.query.address === "string" ? req.query.address.trim() : "";

  if (!address || address.length > 200) {
    return res.status(400).json({
      status: "INVALID_REQUEST",
      error_message: "Address must contain between 1 and 200 characters.",
    });
  }

  const cacheKey = address.toLowerCase();

  if (cache.has(cacheKey)) {
    return res.status(200).json(cache.get(cacheKey));
  }

  const query = new URLSearchParams({
    q: address,
    format: "jsonv2",
    limit: "1",
    addressdetails: "1",
  });

  try {
    const response = await fetch(
      `https://nominatim.openstreetmap.org/search?${query}`,
      {
        headers: {
          "User-Agent":
            "SAWA-Senior-Project/1.0 (https://github.com/majdharb123/Sawa-App)",
          Accept: "application/json",
        },
        signal: AbortSignal.timeout(10000),
      }
    );

    if (!response.ok) {
      console.error("Nominatim HTTP error:", response.status);

      return res.status(502).json({
        status: "UPSTREAM_ERROR",
        error_message: "Geocoding service is temporarily unavailable.",
      });
    }

    const places = await response.json();

    const result =
      places.length === 0
        ? {
            status: "ZERO_RESULTS",
            results: [],
          }
        : {
            status: "OK",
            results: [
              {
                formatted_address: places[0].display_name,
                geometry: {
                  location: {
                    lat: Number.parseFloat(places[0].lat),
                    lng: Number.parseFloat(places[0].lon),
                  },
                },
              },
            ],
          };

    if (cache.size >= 200) {
      const oldestKey = cache.keys().next().value;
      cache.delete(oldestKey);
    }

    cache.set(cacheKey, result);

    return res.status(200).json(result);
  } catch (error) {
    console.error("Geocoding request failed:", error.message);

    return res.status(502).json({
      status: "UPSTREAM_ERROR",
      error_message: "Unable to complete the geocoding request.",
    });
  }
});

module.exports = router;