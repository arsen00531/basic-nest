import { NestFactory } from '@nestjs/core';
import { ConfigService } from '@nestjs/config';
import { AppModule } from './app.module';
import { CustomLogger } from './configs/custom-logger.service';

async function bootstrap() {
  const app = await NestFactory.create(AppModule, {
    logger: new CustomLogger(),
  });
  
  const port: number | string = app.get(ConfigService).getOrThrow('PORT');
  await app.listen(port, () => {
    app.get(CustomLogger).log(`Server is running on port ${port}`);
  });
}
bootstrap();
