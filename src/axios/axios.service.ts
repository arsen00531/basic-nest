import { Injectable, Logger } from '@nestjs/common';
import axios, {
  AxiosError,
  AxiosInstance,
  AxiosRequestConfig,
  AxiosResponse,
} from 'axios';
import axiosRetry from 'axios-retry';

@Injectable()
export class AxiosService {
  private readonly axiosInstance: AxiosInstance;
  private readonly logger = new Logger(AxiosService.name);

  constructor() {
    this.axiosInstance = axios.create();

    // Track request start time
    this.axiosInstance.interceptors.request.use((config) => {
      (config as any).metadata = { startTime: new Date() };
      return config;
    });

    // Setup retry logic, see more details of options: https://github.com/softonic/axios-retry?tab=readme-ov-file#options.
    axiosRetry(this.axiosInstance, {
      retries: 3,
      retryDelay: (retryCount) => retryCount * 1500,
      shouldResetTimeout: true,
      retryCondition: () => true,
      onRetry: (retryCount, error, requestConfig) => {
        const metadata = (requestConfig as any).metadata;
        const duration = new Date().getTime() - metadata.startTime.getTime();
        this.logger.warn(
          `Retry #${retryCount} for request to ${requestConfig.url} failed. Error: ${error.message}. Duration: ${duration}ms`,
        );
      },
    });

    // Log response duration
    this.axiosInstance.interceptors.response.use(
      (response: AxiosResponse) => {
        const metadata = (response.config as any).metadata;
        const duration = new Date().getTime() - metadata.startTime.getTime();
        this.logger.log(
          `Successful ${response.config.method?.toUpperCase()} request to ${response.config.url}. Status: ${
            response.status
          }. Duration: ${duration}ms`,
        );
        return response;
      },
      (error: AxiosError) => {
        const metadata = (error.config as any)?.metadata;
        if (metadata && error.config) {
          const duration = new Date().getTime() - metadata.startTime.getTime();
          this.logger.error(
            `Failed ${error.config.method?.toUpperCase()} request to ${error.config.url}. Error: ${error.message ?? 'Unknown error'}. Duration: ${duration}ms`,
          );
        }
        return Promise.reject(error);
      },
    );
  }

  async request<T = any>(config: AxiosRequestConfig): Promise<T> {
    const response = await this.axiosInstance.request<T>(config);
    return response.data;
  }

  async get<T = any>(url: string, config?: AxiosRequestConfig): Promise<T> {
    return this.request<T>({ ...config, method: 'GET', url });
  }

  async post<T = any>(
    url: string,
    data?: any,
    config?: AxiosRequestConfig,
  ): Promise<T> {
    return this.request<T>({ ...config, method: 'POST', url, data });
  }
}
