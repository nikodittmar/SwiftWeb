# ---- Builder Stage ----
# This stage compiles the Swift application.
# Using Swift 6.0 to match the project's swift-tools-version.
FROM swift:6.0-jammy AS builder

# Set the working directory inside the container.
WORKDIR /app

# Copy the Swift Package Manager manifest.
COPY Package.swift .

# Copy the source code and tests.
COPY Sources/ ./Sources
COPY Tests/ ./Tests

# Build the application in release mode for production.
# This creates a highly optimized executable.
RUN swift build -c release --product __PROJECT_NAME__


# ---- Production Stage ----
# This stage creates the final, lightweight image.
FROM ubuntu:22.04

# Set the working directory for the final image.
WORKDIR /app

# Copy the compiled executable from the builder stage.
# The executable will have the same name as your project.
COPY --from=builder /app/.build/release/__PROJECT_NAME__ .

# Copy the 'Views' directory, which is a necessary resource for your app.
# Your project generator will replace __PROJECT_NAME__ with the actual project name.
COPY --from=builder /app/Sources/__PROJECT_NAME__/Views ./Sources/__PROJECT_NAME__/Views

# Expose the port that the application will run on.
EXPOSE 8080

# The command to run when the container starts.
# This executes your compiled SwiftWeb application and starts the server.
CMD ["./__PROJECT_NAME__", "server"]

