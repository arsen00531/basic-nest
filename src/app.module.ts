import { Module } from '@nestjs/common';
import { ConfigModule } from '@nestjs/config';
import { TypeOrmModule } from '@nestjs/typeorm';
import { getNestConfig } from './configs/nestConfig.config';
import { getTypeormConfig } from './configs/typeorm.config';

@Module({
  imports: [
    ConfigModule.forRoot(getNestConfig()), 
    TypeOrmModule.forRootAsync(getTypeormConfig()), 
  ],
  controllers: [],
  providers: [],
})
export class AppModule {}
