import { router } from '@kit.ArkUI';
import { BusinessError } from '@kit.BasicServicesKit';

@Entry
@Component
struct Index {
  @State message: string = 'Whiteboard';

  build() {
    Row() {
      Column() {
        Button() {
          Text('Appliance Plugin')
            .fontSize(30)
            .fontWeight(FontWeight.Bold)
        }
        .type(ButtonType.Capsule)
        .margin({ top: 20 })
        .backgroundColor('#0D9FFB')
        .width('60%')
        .height('6%')
        .onClick(() => {
          router.pushUrl({ url: 'pages/MultipleBoard' }).then(() => {
            console.info('Succeeded in jumping to the MultipleBoard page.')
          }).catch((err: BusinessError) => {
            console.error(`Failed to jump to the MultipleBoard page. Code is ${err.code}, message is ${err.message}`)
          })
        })
      }
      .width('100%')
    }
    .height('100%')
  }
}
