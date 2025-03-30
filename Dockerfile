FROM mcr.microsoft.com/dotnet/sdk:8.0

# Install PowerShell and curl
RUN apt-get update && \
    apt-get install -y wget apt-transport-https software-properties-common curl && \
    wget -q https://packages.microsoft.com/config/debian/11/packages-microsoft-prod.deb && \
    dpkg -i packages-microsoft-prod.deb && \
    apt-get update && \
    apt-get install -y powershell && \
    rm packages-microsoft-prod.deb && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

WORKDIR /app
COPY RebootAPs.ps1 .

ENTRYPOINT ["pwsh", "-File", "RebootAPs.ps1"]
