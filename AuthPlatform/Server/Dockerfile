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

CMD ["/app/App"]
