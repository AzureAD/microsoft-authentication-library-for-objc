# Build the Vapor service in a reproducible Swift Linux environment.
FROM swift:5.10-jammy AS build
WORKDIR /build

COPY Package.swift ./
RUN swift package resolve

COPY Sources ./Sources
COPY Tests ./Tests
RUN swift build -c release

# Keep the runtime image simple and compatible with Swift's dynamic runtime.
FROM swift:5.10-jammy AS runtime
WORKDIR /app
COPY --from=build /build/.build/release/App /app/App

ENV HOST=0.0.0.0
ENV PORT=8080
EXPOSE 8080

# Render free services do not support one-off/pre-deploy commands.
# Run Fluent migrations over Prisma's direct connection, then serve requests
# over the pooled DATABASE_URL. Both variables must be configured in Render.
CMD ["sh", "-c", ": \"${DATABASE_URL:?DATABASE_URL is required}\"; : \"${DIRECT_DATABASE_URL:?DIRECT_DATABASE_URL is required}\"; DATABASE_URL=\"$DIRECT_DATABASE_URL\" /app/App migrate --yes && exec /app/App"]
