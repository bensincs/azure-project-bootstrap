FROM mcr.microsoft.com/dotnet/sdk:9.0 AS build
WORKDIR /src

# Copy csproj and restore dependencies
COPY api.csproj .
RUN dotnet restore

# Copy everything else and build
COPY . .
RUN dotnet publish -c Release -o /app/publish

# Build runtime image
FROM mcr.microsoft.com/dotnet/aspnet:9.0 AS runtime
WORKDIR /app

# Copy published app
COPY --from=build /app/publish .

# Set environment variables
ENV ASPNETCORE_URLS=http://+:8080
ENV PORT=8080

EXPOSE 8080

ENTRYPOINT ["dotnet", "api.dll"]
