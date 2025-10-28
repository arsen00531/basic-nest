import { FormDataInterceptorConfig, MemoryStoredFile } from 'nestjs-form-data';

export const getNestJsFormDataConfig = (): FormDataInterceptorConfig => ({
  storage: MemoryStoredFile,
  limits: { fileSize: 10 * 1024 * 1024 },
  isGlobal: true,
});
