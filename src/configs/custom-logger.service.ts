import { LoggerService } from '@nestjs/common';

export class CustomLogger implements LoggerService {
  private readonly colors = {
    reset: '\x1b[0m',
    bright: '\x1b[1m',
    red: '\x1b[31m',
    green: '\x1b[32m',
    yellow: '\x1b[33m',
    blue: '\x1b[34m',
    magenta: '\x1b[35m',
    cyan: '\x1b[36m',
    white: '\x1b[37m',
    gray: '\x1b[90m',
  };

  log(message: any, context?: string) {
    const location = this.getCallLocation();
    const timestamp = this.colorize(this.getTimestamp(), this.colors.gray);
    const level = this.colorize('LOG', this.colors.green);
    const contextStr = context ? this.colorize(`[${context}]`, this.colors.cyan) + ' ' : '';
    const locationStr = this.colorize(location, this.colors.gray);
    console.log(`${timestamp} ${level} ${contextStr}${message} ${locationStr}`);
  }

  error(message: any, trace?: string, context?: string) {
    const location = this.getCallLocation();
    const timestamp = this.colorize(this.getTimestamp(), this.colors.gray);
    const level = this.colorize('ERROR', this.colors.red + this.colors.bright);
    const contextStr = context ? this.colorize(`[${context}]`, this.colors.cyan) + ' ' : '';
    const locationStr = this.colorize(location, this.colors.gray);
    console.error(`${timestamp} ${level} ${contextStr}${message} ${locationStr}`);
    if (trace) {
      console.error(this.colorize(trace, this.colors.red));
    }
  }

  warn(message: any, context?: string) {
    const location = this.getCallLocation();
    const timestamp = this.colorize(this.getTimestamp(), this.colors.gray);
    const level = this.colorize('WARN', this.colors.yellow);
    const contextStr = context ? this.colorize(`[${context}]`, this.colors.cyan) + ' ' : '';
    const locationStr = this.colorize(location, this.colors.gray);
    console.warn(`${timestamp} ${level} ${contextStr}${message} ${locationStr}`);
  }

  debug(message: any, context?: string) {
    const location = this.getCallLocation();
    const timestamp = this.colorize(this.getTimestamp(), this.colors.gray);
    const level = this.colorize('DEBUG', this.colors.magenta);
    const contextStr = context ? this.colorize(`[${context}]`, this.colors.cyan) + ' ' : '';
    const locationStr = this.colorize(location, this.colors.gray);
    console.debug(`${timestamp} ${level} ${contextStr}${message} ${locationStr}`);
  }

  verbose(message: any, context?: string) {
    const location = this.getCallLocation();
    const timestamp = this.colorize(this.getTimestamp(), this.colors.gray);
    const level = this.colorize('VERBOSE', this.colors.gray);
    const contextStr = context ? this.colorize(`[${context}]`, this.colors.cyan) + ' ' : '';
    const locationStr = this.colorize(location, this.colors.gray);
    console.log(`${timestamp} ${level} ${contextStr}${message} ${locationStr}`);
  }

  private colorize(text: string, color: string): string {
    return `${color}${text}${this.colors.reset}`;
  }

  private getCallLocation(): string {
    const stack = new Error().stack;
    if (!stack) {
      return '';
    }

    const stackLines = stack.split('\n');
    // Пропускаем первые строки (Error, getCallLocation, методы логгера)
    // Ищем первый вызов, который не относится к самому логгеру
    for (let i = 4; i < stackLines.length; i++) {
      const line = stackLines[i];
      if (line && !line.includes('node_modules') && !line.includes('Logger')) {
        const match = line.match(/at\s+(.+?)\s+\((.+?):(\d+):(\d+)\)/) || 
                      line.match(/at\s+(.+?):(\d+):(\d+)/);
        
        if (match) {
          const filePath = match[2] || match[1];
          const lineNumber = match[3] || match[2];
          const fileName = filePath.split('/').pop() || filePath.split('\\').pop() || filePath;
          return `(${fileName}:${lineNumber})`;
        }
      }
    }
    return '';
  }

  private getTimestamp(): string {
    return new Date().toISOString();
  }
}

