Это просто порт [Gameboy для MiST](https://github.com/mist-devel/gameboy)

* Положите RBF файл в корень SD карты.
* Покладите *.gb|*.gbc файлы в папку Gameboy.

## Возможности
* Поддержка и обычного и цветного Gameboy
* Поддержка Super Gameboy и MegaDuck
* Свои собственные перегородки
* Сохранения
* Перематывания 
* Отмотка - позволяет отмототать до 40 секунд назад
* Убирает моргание в играх (например "Chikyuu Kaihou Gun Zas") 
* Загрузка собственных палитр
* Часы в реальном времени
* Поддержка подключения реального Gameboy
* Читы
* Быстрая загрузка
* Режим GBA для игр GBC

## Исходный код
Бесплатные игры можно скачать [здесь](https://github.com/LIJI32/SameBoy/). Эти ромы достаточно сложно эмулировать. Но для MiSTer это не беда!

 Для максимальной поддержки вы можете положить BIOS в `Bootroms->Load GBC/DMG/SGB boot`. 
Для большей информации на английском прочитайте [предисловие BootROM](./BootROMs/README.md)  
## Палитры
Данное ядро поддерживает собственные палитры (*.gbp) которые могут быть перемещены в папку Gameboy. Некоторые примеры доступны в папке с палитрой.

## Бордюры по экрану
Данное ядро поддерживает бордюры (*.sgb) которые могут быть помещены в папку Gameboy. Некоторые примеры присутствуют в папке borders

## Авто-загрузка
Чтобы загрудать автоматически ваши любимые игры просто перейменуте их в `boot2.rom`.

## Видео выход
The Gameboy can disable video output at any time which causes problems with vsync_adjust=2 or analog video during screen transitions. Enabling the Stabilize video option may fix this at the cost of some increased latency.
Gameboy может отключать видео выход в любую секунду что делает проблемы с VSync а также ЭЛТ мониторами. Включайте опцию `Stabilize video` и не думайте об проблемах!
# Сохранения
This core provides 4 slots to save and restore the memory state which means you can save at any point in the game. These can be saved to your SDCard or they can reside only in memory for temporary use (OSD Option). Save states can be performed with the Keyboard, a mapped button to a gamepad, or through the OSD.

Keyboard Hotkeys for save states:
- Alt+F1 thru Alt+F4 - save state
- F1 thru F4 - restore state

Gamepad:
- Savestatebutton+Left or Right switches the savestate slot
- Savestatebutton+Start+Down saves to the selected slot
- Savestatebutton+Start+Up loads from the selected slot

Данное ядро даёт 4 слота для сохранений.
На клавиатуре:
- Alt+F1 - сохранить
- F1 - загрузить
Геймпад
- Сохранить+лево или право переключает слот
- Сохранить+Старт+Вниз сохранить
- Сохранить+Старт+Вверх загрузить

# Видео инструкция
[Pixel_Devil Live](https://www.youtube.com/watch?v=fGj1BLjUk4c&t=2s) [Gaming Corner](https://www.youtube.com/watch?v=Qv4B4KhoPR0&t=5s) [Oleg Kerman](https://www.youtube.com/watch?v=Zz5heUO8h0g&t=2s)
