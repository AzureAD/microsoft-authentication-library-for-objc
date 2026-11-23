# Build the Vapor service with the Swift 6.2 toolchain used by CI.
FROM swift:6.2-noble AS build
WORKDIR /build

COPY Package.swift ./
RUN swift package resolve

COPY Sources ./Sources
COPY Tests ./Tests
RUN swift build -c release

# Runtime image retains the Swift runtime required by the executable.
FROM swift:6.2-noble AS runtime
WORKDIR /app
COPY --from=build /build/.build/release/App /app/App

# Railway injects PORT at runtime; HOST keeps Vapor reachable externally.
ENV HOST=0.0.0.0
ENV PORT=8080
EXPOSE 8080

# Migrate with the direct PostgreSQL connection, then serve using DATABASE_URL.
CMD ["sh", "-c", ": \"${DATABASE_URL:?DATABASE_URL is required}\"; : \"${DIRECT_DATABASE_URL:?DIRECT_DATABASE_URL is required}\"; DATABASE_URL=\"$DIRECT_DATABASE_URL\" /app/App migrate --yes && exec /app/App"]
