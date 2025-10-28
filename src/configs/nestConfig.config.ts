import { ConfigModuleOptions } from '@nestjs/config';

export const getNestConfig = (): ConfigModuleOptions => ({
  isGlobal: true,
  envFilePath: [
    `.env.${process.env.NODE_ENV}`,
    process.env.NODE_ENV === 'development' ? '.env' : '',
  ],
});
