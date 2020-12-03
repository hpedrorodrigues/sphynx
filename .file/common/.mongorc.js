const status = db.serverStatus();

prompt = () => `${db}@${status.host}[Uptime - ${status.uptime}s]$ `;
