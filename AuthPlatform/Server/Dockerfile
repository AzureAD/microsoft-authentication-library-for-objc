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

ENV HOST=0.0.0.0
ENV PORT=10000
EXPOSE 10000

# Run schema migrations as a controlled release operation before serving traffic.
CMD ["/app/App"]
